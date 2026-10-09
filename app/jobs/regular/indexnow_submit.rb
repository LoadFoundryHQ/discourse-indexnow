# frozen_string_literal: true

module Jobs
  class IndexNowSubmit < ::Jobs::Base
    def execute(args)
      urls = Array(args[:urls]).map(&:to_s).reject(&:empty?)
      return if urls.empty?

      IndexNow::Engine.submit(urls, trigger: args[:trigger].presence || "auto")
    end
  end
end
