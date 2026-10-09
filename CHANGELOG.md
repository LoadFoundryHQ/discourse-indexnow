# Changelog

## 1.3.0

Phase 2 — dashboard analytics:
- **Last 7 days trend** (successful vs failed per day).
- **Failure reasons** breakdown.

## 1.2.0

Phase 1 — dashboard tools:
- **Manual submission**: paste URLs (one per line) to submit specific links; only URLs on the site are accepted.
- **Backfill preview**: see how many topics match (by category/date) before running the backfill.
- **Per-URL cooldown** (`indexnow_url_cooldown_minutes`): avoids resubmitting the same URL too quickly.

## 1.1.6

- Hidden the `indexnow_hourly_limit` and `indexnow_daily_limit` settings from the panel; over-quota batches are retried automatically, so no manual tuning is needed.

## 1.1.5

- Hidden the technical settings `indexnow_key` and `indexnow_endpoint` from the settings panel; both are managed from the IndexNow dashboard.

## 1.1.4

- Rate limits no longer mark batches as **failed**: over-quota batches are **re-queued** (retried in 15 minutes) instead of recorded as failures.
- Default hourly limit is now **0 (no limit)**; the daily limit stays 10,000. Set a positive hourly value to throttle.

## 1.1.3

- Fixed the background jobs: moved them to `lib/indexnow/jobs.rb` (`Jobs::IndexNowSubmit`, `Jobs::IndexNowBackfill`) and required them explicitly, since Discourse does not reliably autoload plugin `app/jobs`.

## 1.1.2

- Moved the submission log model to `lib/indexnow/log.rb` (`IndexNow::Log`) and required it explicitly, since Discourse does not reliably autoload plugin `app/models`.

## 1.1.1

- Fixed autoload/migration naming: file names now match the `IndexNow` constants (migration `create_index_now_logs`, model `index_now_log`, jobs `index_now_submit` / `index_now_backfill`).

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
