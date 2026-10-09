# Changelog

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
