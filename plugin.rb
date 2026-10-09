# frozen_string_literal: true

# name: discourse-indexnow
# about: Load Foundry IndexNow — notify IndexNow search engines (Bing, Yandex, Seznam, Naver) as soon as your topics are created, edited or deleted.
# version: 1.0.3
# authors: Load Foundry
# url: https://github.com/LoadFoundryHQ/discourse-indexnow
# required_version: 3.2.0

enabled_site_setting :indexnow_enabled

require_relative "lib/indexnow/engine"

after_initialize do
  require_relative "lib/indexnow/key_controller"

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
  end

  DiscourseEvent.on(:post_created) { |post| IndexNow::Engine.on_post_created(post) }
  DiscourseEvent.on(:post_edited) { |post| IndexNow::Engine.on_post_changed(post) }
  DiscourseEvent.on(:post_destroyed) { |post| IndexNow::Engine.on_post_changed(post) }
  DiscourseEvent.on(:topic_destroyed) { |topic| IndexNow::Engine.on_topic_destroyed(topic) }
end
