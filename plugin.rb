# frozen_string_literal: true

# name: discourse-indexnow
# about: Load Foundry IndexNow — notify IndexNow search engines (Bing, Yandex, Seznam, Naver) as soon as your topics are created, edited or deleted, with an admin dashboard and historical backfill.
# version: 1.1.3
# authors: Load Foundry
# url: https://github.com/LoadFoundryHQ/discourse-indexnow
# required_version: 3.2.0

enabled_site_setting :indexnow_enabled

register_asset "stylesheets/indexnow.scss", :admin

require_relative "lib/indexnow/engine"

add_admin_route "indexnow.title", "discourse-indexnow", use_new_show_route: true

after_initialize do
  require_relative "lib/indexnow/log"
  require_relative "lib/indexnow/jobs"
  require_relative "lib/indexnow/key_controller"
  require_relative "lib/indexnow/admin_controller"
  require_relative "lib/indexnow/backfill"
  require_relative "lib/indexnow/key_check"

  # Auto-generate a key the first time the plugin runs, so it works out of the box.
  if SiteSetting.indexnow_enabled && SiteSetting.indexnow_key.blank?
    SiteSetting.indexnow_key = SecureRandom.hex(16)
  end

  Discourse::Application.routes.append do
    # IndexNow requires the key file at the domain root: https://host/<key>.txt
    get "/:key" => "index_now/key#show",
        constraints: {
          key: /[0-9a-fA-F]{8,128}\.txt/,
        },
        format: false
    # Friendly alias on a subpath (same content).
    get "/indexnow/:key" => "index_now/key#show"

    scope "/admin/plugins/indexnow", defaults: { format: :json } do
      get "/status" => "index_now/admin#status"
      get "/logs" => "index_now/admin#logs"
      post "/verify" => "index_now/admin#verify_key"
      post "/generate" => "index_now/admin#generate_key"
      post "/backfill" => "index_now/admin#backfill"
    end

    # Full-page loads of the admin dashboard render the admin SPA.
    get "/admin/plugins/discourse-indexnow/indexnow" => "admin/plugins#show",
        constraints: {
          plugin_id: "discourse-indexnow",
        }
  end

  DiscourseEvent.on(:post_created) { |post| IndexNow::Engine.on_post_created(post) }
  DiscourseEvent.on(:post_edited) { |post| IndexNow::Engine.on_post_changed(post) }
  DiscourseEvent.on(:post_destroyed) { |post| IndexNow::Engine.on_post_changed(post) }
  DiscourseEvent.on(:topic_destroyed) { |topic| IndexNow::Engine.on_topic_destroyed(topic) }
end
