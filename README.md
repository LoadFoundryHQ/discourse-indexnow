# Load Foundry IndexNow

A **Load Foundry** plugin for Discourse that notifies **IndexNow** search engines — **Bing, Yandex, Seznam and Naver** — the moment your topics are created, edited or deleted. Fresh content gets crawled (and removed content gets dropped) much faster than waiting for the next scheduled crawl.

## Features

- **Instant notifications** to IndexNow whenever a topic, post or edit changes a topic.
- **Handles removals**: when a topic is deleted, its URL is submitted so engines can drop it.
- **Only public content**: private messages and topics in restricted categories are never submitted.
- **Background job**: submissions run asynchronously (never block a request) and never break your forum if the API is down.
- **Zero configuration**: a key is generated automatically on first run and served at `/indexnow/<key>` for verification.
- **Multilingual** admin descriptions (English / Español / Português).

## How IndexNow works

1. The plugin hosts your **key** at `https://your-forum/indexnow/<key>`.
2. When a topic changes, it `POST`s the topic URL to `https://api.indexnow.org/indexnow` with your host, key, `keyLocation` and `urlList`.
3. **Bing, Yandex, Seznam and Naver** are notified through the shared IndexNow endpoint.

## Installation

Add to your `containers/app.yml` (inside `hooks: after_code:`):

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/LoadFoundryHQ/discourse-indexnow.git
```

Then rebuild:

```bash
cd /var/discourse
./launcher rebuild app
```

## Configuration

Admin → Settings → Plugins → **Load Foundry IndexNow**:

| Setting | Default | Description |
|---|---|---|
| `indexnow_enabled` | `true` | Enable/disable the plugin. |
| `indexnow_key` | *(auto)* | IndexNow key, served at `/indexnow/<key>`. Auto-generated if empty. |
| `indexnow_endpoint` | `https://api.indexnow.org/indexnow` | IndexNow API endpoint. |
| `indexnow_submit_on_create` | `true` | Submit when a topic/post is created. |
| `indexnow_submit_on_update` | `true` | Submit when a post is edited or a topic is deleted. |

## Verifying

Visit `https://your-forum/indexnow/<your-key>` — it should return your key as plain text. IndexNow uses this to confirm you own the domain.

## Notes

- Submissions are **best-effort**: if the IndexNow API is unreachable, the forum keeps working (errors are logged, never raised).
- IndexNow is a shared protocol; individual engines may still take a little time to reflect changes, but far less than a normal crawl.

## License

MIT — see [LICENSE](LICENSE). © Load Foundry (Xolvora).
