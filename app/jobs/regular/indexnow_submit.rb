# frozen_string_literal: true

module Jobs
  class IndexNowSubmit < ::Jobs::Base
    def execute(args)
      url = args[:url].to_s
      return if url.blank?

      IndexNow::Engine.submit([url])
    end
  end
end
