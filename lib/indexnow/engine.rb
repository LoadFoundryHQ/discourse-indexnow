# frozen_string_literal: true

module IndexNow
  # Submits topic URLs to the IndexNow API so search engines are notified
  # immediately when public content is created, updated or removed.
  class Engine
    DEFAULT_ENDPOINT = "https://api.indexnow.org/indexnow"

    def self.enabled?
      SiteSetting.indexnow_enabled && SiteSetting.indexnow_key.present?
    end

    def self.on_post_created(post)
      return unless enabled? && SiteSetting.indexnow_submit_on_create
      enqueue(post&.topic)
    end

    def self.on_post_changed(post)
      return unless enabled? && SiteSetting.indexnow_submit_on_update
      enqueue(post&.topic)
    end

    def self.on_topic_destroyed(topic)
      return unless enabled? && SiteSetting.indexnow_submit_on_update
      return if topic.blank?
      enqueue(topic, removed: true)
    end

    def self.enqueue(topic, removed: false)
      return if topic.blank?
      return unless removed || public_topic?(topic)

      url = topic_url(topic)
      return if url.blank?

      Jobs.enqueue(:indexnow_submit, url: url)
    end

    def self.public_topic?(topic)
      return false if topic.private_message?

      category = topic.category
      return true if category.nil?

      !category.read_restricted?
    end

    def self.topic_url(topic)
      "#{Discourse.base_url}#{topic.relative_url}"
    end

    # Performs the actual POST to IndexNow. Returns the HTTP status or nil.
    def self.submit(urls)
      urls = Array(urls).map(&:to_s).uniq.reject(&:empty?)
      return if urls.empty?

      key = SiteSetting.indexnow_key
      return if key.blank?

      host = host_from_base_url
      return if host.blank?

      payload = {
        host: host,
        key: key,
        keyLocation: "#{Discourse.base_url}/#{key}.txt",
        urlList: urls,
      }

      response =
        Excon.post(
          SiteSetting.indexnow_endpoint.presence || DEFAULT_ENDPOINT,
          body: payload.to_json,
          headers: { "Content-Type" => "application/json" },
          connect_timeout: 5,
          read_timeout: 15,
        )

      response.status
    rescue StandardError => e
      Rails.logger.warn(
        "discourse-indexnow: submit failed (#{e.class}: #{e.message})",
      )
      nil
    end

    def self.host_from_base_url
      host = URI.parse(Discourse.base_url).host.to_s
      return if host.empty? || host == "localhost" || host.start_with?("127.")

      host
    rescue StandardError
      nil
    end
  end
end
