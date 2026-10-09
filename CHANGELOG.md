# Changelog

## 1.1.0

- **Admin dashboard** (Admin → Plugins → Load Foundry IndexNow): status, key file URL, verify key, generate a new key, today's success/failed counts, recent submissions log, and historical backfill.
- **Historical backfill**: queue all public topics (optionally filtered by category and date) in 10,000-URL batches.
- **Batching, rate limits and Retry-After**: URLs are chunked into a single `urlList`; hourly/daily limits are enforced; IndexNow `429` applies a temporary global throttle.
- **Exclusions**: `indexnow_excluded_category_ids` and `indexnow_excluded_tag_names`; also skips login-required sites, private messages, restricted/unlisted/deleted topics.
- **Key accessibility check** and **key rotation**.

## 1.0.3

- **Serve the key file at the domain root** (`/<key>.txt`), which is what IndexNow requires for verification; `keyLocation` now points there. The `/indexnow/<key>` alias is kept for convenience.

## 1.0.2

- Fixed the key endpoint controller reference: use the `index_now` namespace so it resolves to the `IndexNow` module (Discourse/Rails camelizes route namespaces).

## 1.0.1

- Fixed the public key endpoint (`/indexnow/<key>`): the controller now lives under `lib/indexnow/` and is required explicitly, matching Discourse's plugin controller convention.

## 1.0.0

- Initial release: **Load Foundry IndexNow**.
- Notifies IndexNow search engines (Bing, Yandex, Seznam, Naver) when topics are created, edited or deleted.
- Public key file served at `/indexnow/<key>`; the key is auto-generated on first run.
- Submissions run in a background job; only public content is submitted.
- Settings are documented in English, Español and Português.
