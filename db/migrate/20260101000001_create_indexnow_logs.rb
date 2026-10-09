# frozen_string_literal: true

class CreateIndexNowLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :indexnow_logs do |t|
      t.string :url, null: false
      t.string :status, null: false, default: "success"
      t.integer :response_code
      t.string :error
      t.string :trigger
      t.timestamps
    end

    add_index :indexnow_logs, :created_at
    add_index :indexnow_logs, :status
  end
end
