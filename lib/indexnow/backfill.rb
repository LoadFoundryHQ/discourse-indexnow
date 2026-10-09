# frozen_string_literal: true

module IndexNow
  class Backfill
    def self.run(category_id: nil, since: nil)
      scope = Topic.listable_topics.where(archetype: Archetype.default, deleted_at: nil)
      scope = scope.where(category_id: category_id.to_i) if category_id.present?

      if since.present?
        time = Time.zone.parse(since.to_s) rescue nil
        scope = scope.where("topics.created_at >= ?", time) if time
      end

      urls = []
      scope.find_each(batch_size: 1000) do |topic|
        next unless Engine.topic_allowed?(topic)
        urls << Engine.topic_url(topic)
      end

      urls.each_slice(Engine::CHUNK_SIZE) { |chunk| Jobs.enqueue(:indexnow_submit, urls: chunk, trigger: "backfill") }
      urls.size
    end
  end
end
