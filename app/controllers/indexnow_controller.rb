# frozen_string_literal: true

class IndexnowController < ApplicationController
  skip_before_action :check_xhr, raise: false
  skip_before_action :redirect_to_login_if_required, raise: false

  # Serves the IndexNow key file so search engines can verify ownership.
  # Public URL: /indexnow/<key>
  def key
    expected = SiteSetting.indexnow_key.to_s
    provided = params[:key].to_s

    if expected.present? &&
         ActiveSupport::SecurityUtils.secure_compare(provided, expected)
      render plain: expected, content_type: "text/plain"
    else
      raise Discourse::NotFound
    end
  end
end
