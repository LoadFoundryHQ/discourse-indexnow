# frozen_string_literal: true

module IndexNow
  class AdminController < Admin::AdminController
    def status
      day_start = Time.zone.now.beginning_of_day
      key = SiteSetting.indexnow_key.to_s

      render json: {
        "enabled" => SiteSetting.indexnow_enabled,
        "key" => key,
        "key_url" => "#{Discourse.base_url}/#{key}.txt",
        "key_accessible" => Discourse.cache.read("indexnow:key_accessible"),
        "today_success" =>
          IndexNow::Log.successful.since(day_start).count,
        "today_failed" => IndexNow::Log.failed.since(day_start).count,
        "total" => IndexNow::Log.count,
        "hourly_limit" => SiteSetting.indexnow_hourly_limit,
        "daily_limit" => SiteSetting.indexnow_daily_limit,
      }
    end

    def logs
      logs =
        IndexNow::Log.recent.limit(100).map do |log|
          {
            "id" => log.id,
            "url" => log.url,
            "status" => log.status,
            "response_code" => log.response_code,
            "error" => log.error,
            "trigger" => log.trigger,
            "created_at" => log.created_at.iso8601,
          }
        end

      render json: { "logs" => logs }
    end

    def stats
      days = 7
      start = (days - 1).days.ago.beginning_of_day

      raw =
        IndexNow::Log
          .where("created_at >= ?", start)
          .group("date(created_at)", :status)
          .count

      trend =
        (0...days).map do |i|
          date = (days - 1 - i).days.ago.to_date
          {
            "date" => date.iso8601,
            "success" => raw[[date, "success"]] || 0,
            "failed" => raw[[date, "failed"]] || 0,
          }
        end

      failures =
        IndexNow::Log
          .failed
          .since(start)
          .group(:error)
          .count
          .map { |reason, count| { "reason" => reason.presence || "unknown", "count" => count } }
          .sort_by { |entry| -entry["count"] }
          .first(10)

      render json: { "trend" => trend, "failures" => failures }
    end

    def verify_key
      result = KeyCheck.run
      Discourse.cache.write("indexnow:key_accessible", result["accessible"], expires_in: 1.hour)
      render json: result
    end

    def generate_key
      key = SecureRandom.hex(16)
      SiteSetting.indexnow_key = key
      Discourse.cache.delete("indexnow:key_accessible")
      render json: { "key" => key, "key_url" => "#{Discourse.base_url}/#{key}.txt" }
    end

    def backfill
      Jobs.enqueue(
        :index_now_backfill,
        category_id: params[:category_id].presence,
        since: params[:since].presence,
      )
      render json: { "ok" => true }
    end

    def backfill_preview
      count =
        Backfill.count(
          category_id: params[:category_id].presence,
          since: params[:since].presence,
        )
      render json: { "count" => count }
    end

    def refresh_category
      category_id = params[:category_id].to_i
      if category_id <= 0
        return render json: { "ok" => false, "error" => "category_id required" }, status: 400
      end

      Jobs.enqueue(:index_now_category_refresh, category_id: category_id)
      render json: { "ok" => true }
    end

    MAX_MANUAL_URLS = 10_000

    def submit_manual
      urls =
        params[:urls]
          .to_s
          .split(/[\r\n]+/)
          .map(&:strip)
          .reject(&:empty?)
          .first(MAX_MANUAL_URLS)

      count = Engine.enqueue_many(urls, "manual")
      render json: { "ok" => true, "count" => count }
    end
  end
end
