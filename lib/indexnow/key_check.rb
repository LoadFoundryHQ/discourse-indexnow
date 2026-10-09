# frozen_string_literal: true

module IndexNow
  class KeyCheck
    def self.run
      key = SiteSetting.indexnow_key.to_s
      url = "#{Discourse.base_url}/#{key}.txt"
      return { "accessible" => false, "error" => "no_key", "url" => url } if key.blank?

      response =
        Excon.get(
          url,
          headers: { "User-Agent" => "LoadFoundry-IndexNow-KeyCheck/1.0" },
          connect_timeout: 5,
          read_timeout: 10,
        )
      accessible = response.status == 200 && response.body.to_s.strip == key
      { "accessible" => accessible, "http_status" => response.status, "url" => url }
    rescue StandardError => e
      { "accessible" => false, "error" => e.message, "url" => url }
    end
  end
end
