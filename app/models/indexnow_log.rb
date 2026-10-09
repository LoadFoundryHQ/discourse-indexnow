# frozen_string_literal: true

class IndexNowLog < ActiveRecord::Base
  self.table_name = "indexnow_logs"

  scope :recent, -> { order(created_at: :desc) }
  scope :since, ->(time) { where("created_at >= ?", time) }
  scope :successful, -> { where(status: "success") }
  scope :failed, -> { where(status: "failed") }
end
