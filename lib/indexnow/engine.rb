# frozen_string_literal: true

module IndexNow
  class Engine
    DEFAULT_ENDPOINT = "https://api.indexnow.org/indexnow"
    CHUNK_SIZE = 10_000
    THROTTLE_KEY = "indexnow:throttle_until"
    HOUR_KEY = "indexnow:quota:hour"
    DAY_KEY = "indexnow:quota:day"

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
        enqueue(topic_url(topic), "delete")
      end

      def submit_post(post, trigger)
        return unless enabled?
        topic = post&.topic
        return if topic.blank?
        return unless topic_allowed?(topic)
        enqueue(topic_url(topic), trigger)
      end

      def enqueue(url, trigger)
        return if url.blank?
        Jobs.enqueue(:indexnow_submit, urls: [url], trigger: trigger.to_s)
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
            record(chunk, 429, "quota_exceeded", trigger)
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
        IndexNowLog.insert_all(rows) if rows.present?
      rescue StandardError => e
        Rails.logger.warn("discourse-indexnow: log failed (#{e.class}: #{e.message})")
      end

      def reserve_quota(count)
        hour = discourse_count(HOUR_KEY)
        day = discourse_count(DAY_KEY)
        return false if hour + count > SiteSetting.indexnow_hourly_limit
        return false if day + count > SiteSetting.indexnow_daily_limit

        Discourse.cache.write(HOUR_KEY, hour + count, expires_in: 1.hour + 5.minutes)
        Discourse.cache.write(DAY_KEY, day + count, expires_in: 25.hours)
        true
      end

      def discourse_count(key)
        Discourse.cache.read(key).to_i
      end

      def throttled?
        until_ts = Discourse.cache.read(THROTTLE_KEY).to_i
        until_ts.positive? && Time.now.to_i < until_ts
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
