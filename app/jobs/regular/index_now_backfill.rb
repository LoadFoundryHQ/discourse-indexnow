# frozen_string_literal: true

module Jobs
  class IndexNowBackfill < ::Jobs::Base
    def execute(args)
      IndexNow::Backfill.run(category_id: args[:category_id], since: args[:since])
    end
  end
end
