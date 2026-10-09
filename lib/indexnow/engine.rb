# frozen_string_literal: true

module IndexNow
  class Engine
    DEFAULT_ENDPOINT = "https://api.indexnow.org/indexnow"
    CHUNK_SIZE = 10_000
    THROTTLE_KEY = "indexnow:throttle_until"
    HOUR_KEY = "indexnow:quota:hour"
    DAY_KEY = "indexnow:quota:day"
    COOLDOWN_KEY = "indexnow:cooldown"

    class << self
      def enabled?
        return false unless SiteSetting.indexnow_enabled
        return false if SiteSetting.indexnow_key.blank?
        return false if SiteSetting.login_required
        true
      end

      def on_post_created(post)
        if post.post_number.to_i <= 1
          return unless SiteSetting.indexnow_submit_on_create
          submit_post(post, "create")
        else
          return unless SiteSetting.indexnow_submit_on_reply
          submit_post(post, "reply")
        end
      end

      def on_post_changed(post)
        return unless SiteSetting.indexnow_submit_on_update
        submit_post(post, "edit")
      end

      def on_topic_destroyed(topic)
        return unless SiteSetting.indexnow_submit_on_update
        return if topic.blank?
        enqueue_urls(topic_urls(topic), "delete")
      end

      def submit_post(post, trigger)
        return unless enabled?
        topic = post&.topic
        return if topic.blank?
        return unless topic_allowed?(topic)
        enqueue_urls(topic_urls(topic), trigger)
      end

      def on_topic_changed(topic)
        return unless enabled? && SiteSetting.indexnow_submit_on_update
        return if topic.blank?
        return unless topic_allowed?(topic)
        enqueue_urls(topic_urls(topic), "update")
      end

      def on_topic_removed(topic)
        return unless enabled? && SiteSetting.indexnow_submit_on_update
        return if topic.blank?
        enqueue_urls(topic_urls(topic), "delete")
      end

      # Re-submits every topic of a category so engines re-evaluate them
      # (e.g. after a category changes visibility).
      def refresh_category(category_id)
        return unless enabled?
        category_id = category_id.to_i
        return 0 if category_id <= 0

        urls = []
        Topic
          .where(category_id: category_id, archetype: Archetype.default, deleted_at: nil)
          .find_each(batch_size: 1000) { |topic| urls.concat(topic_urls(topic)) }

        urls.each_slice(CHUNK_SIZE) do |chunk|
          Jobs.enqueue(:index_now_submit, urls: chunk, trigger: "category")
        end
        urls.size
      end

      def enqueue_urls(urls, trigger)
        urls = Array(urls).map(&:to_s).uniq.reject(&:empty?)
        urls = urls.reject { |url| within_cooldown?(url) }
        return if urls.empty?

        urls.each { |url| mark_cooldown(url) }
        Jobs.enqueue(:index_now_submit, urls: urls, trigger: trigger.to_s)
      end

      # Main topic URL plus a `?tl=<locale>` variant per locale when Discourse
      # Content Localization (crawler param) is enabled.
      def topic_urls(topic)
        base = topic_url(topic)
        locales = localized_locales
        return [base] if locales.empty?

        [base] + locales.map { |locale| "#{base}?tl=#{locale}" }
      end

      def localized_locales
        return [] unless SiteSetting.respond_to?(:content_localization_enabled)
        return [] unless SiteSetting.content_localization_enabled
        return [] unless SiteSetting.respond_to?(:content_localization_crawler_param)
        return [] unless SiteSetting.content_localization_crawler_param

        SiteSetting
          .content_localization_supported_locales
          .to_s
          .split(/[|,]/)
          .map(&:strip)
          .reject(&:empty?)
      end

      def enqueue(url, trigger, respect_cooldown: true)
        return if url.blank?
        return if respect_cooldown && within_cooldown?(url)

        mark_cooldown(url)
        Jobs.enqueue(:index_now_submit, urls: [url], trigger: trigger.to_s)
      end

      def enqueue_many(urls, trigger)
        urls = Array(urls).map(&:to_s).uniq.select { |u| valid_url?(u) }
        return 0 if urls.empty?

        Jobs.enqueue(:index_now_submit, urls: urls, trigger: trigger.to_s)
        urls.size
      end

      def valid_url?(url)
        uri = URI.parse(url.to_s)
        return false unless uri.is_a?(URI::HTTP) && uri.host.present?

        uri.host == URI.parse(Discourse.base_url).host
      rescue StandardError
        false
      end

      def submit(urls, trigger: "manual")
        urls = Array(urls).map(&:to_s).uniq.reject(&:empty?)
        return if urls.empty?

        host = host_from_base_url
        key = SiteSetting.indexnow_key
        return if host.blank? || key.blank?

        if throttled?
          record(urls, 429, "throttled", trigger)
          return 429
        end

        last_status = nil
        urls.each_slice(CHUNK_SIZE) do |chunk|
          unless reserve_quota(chunk.size)
            requeue(chunk, trigger)
            last_status = 429
            next
          end

          status, error =
            perform_request(host: host, key: key, url_list: chunk)
          last_status = status
          record(chunk, status, error, trigger)
          apply_retry_after(status)
        end
        last_status
      end

      def topic_url(topic)
        "#{Discourse.base_url}#{topic.relative_url}"
      end

      def topic_allowed?(topic)
        return false if topic.blank?
        return false if topic.private_message?
        return false if topic.deleted_at.present?
        return false if topic.respond_to?(:visible) && topic.visible == false

        category = topic.category
        if category
          return false if category.read_restricted?
          return false if excluded_category_ids.include?(category.id)
        end

        if excluded_tag_names.present?
          names = (topic.respond_to?(:tags) ? topic.tags.map(&:name) : [])
          return false if (names & excluded_tag_names).any?
        end

        true
      end

      def excluded_category_ids
        SiteSetting
          .indexnow_excluded_category_ids
          .to_s
          .split(/[|,]/)
          .map(&:to_i)
          .reject(&:zero?)
      end

      def excluded_tag_names
        SiteSetting.indexnow_excluded_tag_names.to_s.split(/[|,]/).map(&:strip).reject(&:empty?)
      end

      private

      def perform_request(host:, key:, url_list:)
        response =
          Excon.post(
            SiteSetting.indexnow_endpoint.presence || DEFAULT_ENDPOINT,
            body: {
              host: host,
              key: key,
              keyLocation: "#{Discourse.base_url}/#{key}.txt",
              urlList: url_list,
            }.to_json,
            headers: { "Content-Type" => "application/json" },
            connect_timeout: 5,
            read_timeout: 20,
          )

        if response.status.between?(200, 299)
          [response.status, nil]
        else
          [response.status, truncate(response.body)]
        end
      rescue StandardError => e
        Rails.logger.warn("discourse-indexnow: submit failed (#{e.class}: #{e.message})")
        [nil, "#{e.class}: #{e.message}"]
      end

      def record(urls, status, error, trigger)
        ok = status.present? && status.between?(200, 299)
        now = Time.zone.now
        rows =
          urls.map do |url|
            {
              url: url.to_s[0, 1000],
              status: ok ? "success" : "failed",
              response_code: status,
              error: error.to_s[0, 500].presence,
              trigger: trigger.to_s,
              created_at: now,
              updated_at: now,
            }
          end
        IndexNow::Log.insert_all(rows) if rows.present?
      rescue StandardError => e
        Rails.logger.warn("discourse-indexnow: log failed (#{e.class}: #{e.message})")
      end

      def reserve_quota(count)
        hour_limit = SiteSetting.indexnow_hourly_limit.to_i
        day_limit = SiteSetting.indexnow_daily_limit.to_i
        hour = discourse_count(HOUR_KEY)
        day = discourse_count(DAY_KEY)

        return false if hour_limit.positive? && hour + count > hour_limit
        return false if day_limit.positive? && day + count > day_limit

        Discourse.cache.write(HOUR_KEY, hour + count, expires_in: 1.hour + 5.minutes)
        Discourse.cache.write(DAY_KEY, day + count, expires_in: 25.hours)
        true
      end

      def requeue(chunk, trigger)
        Jobs.enqueue_in(15.minutes, :index_now_submit, urls: chunk, trigger: trigger.to_s)
      end

      def discourse_count(key)
        Discourse.cache.read(key).to_i
      end

      def throttled?
        until_ts = Discourse.cache.read(THROTTLE_KEY).to_i
        until_ts.positive? && Time.now.to_i < until_ts
      end

      def within_cooldown?(url)
        minutes = SiteSetting.indexnow_url_cooldown_minutes.to_i
        return false if minutes <= 0

        Discourse.cache.read(cooldown_key(url)).present?
      end

      def mark_cooldown(url)
        minutes = SiteSetting.indexnow_url_cooldown_minutes.to_i
        return if minutes <= 0

        Discourse.cache.write(cooldown_key(url), 1, expires_in: minutes.minutes)
      end

      def cooldown_key(url)
        "#{COOLDOWN_KEY}:#{Digest::SHA1.hexdigest(url.to_s)}"
      end

      def apply_retry_after(status)
        return unless status == 429
        seconds = 300
        Discourse.cache.write(THROTTLE_KEY, Time.now.to_i + seconds, expires_in: seconds + 60)
      end

      def host_from_base_url
        host = URI.parse(Discourse.base_url).host.to_s
        return if host.empty? || host == "localhost" || host.start_with?("127.")

        host
      rescue StandardError
        nil
      end

      def truncate(text)
        text.to_s[0, 500]
      end
    end
  end
end
