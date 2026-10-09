# frozen_string_literal: true

module IndexNow
  class Backfill
    def self.run(category_id: nil, since: nil)
      batch = []
      total = 0
      topic_scope(category_id: category_id, since: since).find_each(batch_size: 500) do |topic|
        next unless Engine.topic_allowed?(topic)
        batch.concat(Engine.topic_urls(topic))
        total += 1
        Engine.flush_batch(batch, "backfill")
      end
      Engine.flush_batch(batch, "backfill", final: true)
      total
    end

    def self.count(category_id: nil, since: nil)
      total = 0
      topic_scope(category_id: category_id, since: since).find_each(batch_size: 1000) do |topic|
        total += 1 if Engine.topic_allowed?(topic)
      end
      total
    end

    def self.topic_scope(category_id:, since:)
      scope =
        Topic
          .listable_topics
          .where(archetype: Archetype.default, deleted_at: nil)
          .includes(:category, :tags)
      scope = scope.where(category_id: category_id.to_i) if category_id.present?

      if since.present?
        time = begin
          Time.zone.parse(since.to_s)
        rescue StandardError
          nil
        end
        scope = scope.where("topics.created_at >= ?", time) if time
      end

      scope
    end
  end
end
