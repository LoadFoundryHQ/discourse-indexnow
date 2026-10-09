# frozen_string_literal: true

module Jobs
  class IndexNowSubmit < ::Jobs::Base
    def execute(args)
      urls = Array(args[:urls]).map(&:to_s).reject(&:empty?)
      return if urls.empty?

      IndexNow::Engine.submit(urls, trigger: args[:trigger].presence || "auto")
    end
  end

  class IndexNowBackfill < ::Jobs::Base
    def execute(args)
      IndexNow::Backfill.run(category_id: args[:category_id], since: args[:since])
    end
  end

  class IndexNowCategoryRefresh < ::Jobs::Base
    def execute(args)
      IndexNow::Engine.refresh_category(args[:category_id]) if args[:category_id].present?
    end
  end
end
