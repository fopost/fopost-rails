# Changelog

All notable changes to this gem are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the gem follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-10-18

### Added

- `POST /fopost/articles` on the mounted engine receives the blog's website target. The `fopost`
  gem verifies the signature; `article.published` reaches `config.on_article_published` and the
  `fopost.article.published` notification, and a returned URL is echoed as `{ "url": ... }`.
- `website_secret` setting (`FOPOST_WEBSITE_SECRET`), falling back to `webhook_secret`.

### Changed

- Requires `fopost` `~> 0.3`, now resolved from RubyGems instead of the GitHub source.
- The README points at `fopost.com/dashboard` instead of the retired app host.

## [0.1.0] - 2026-08-30

Initial release.

- `Fopost::Rails.configure` and `config.fopost`, resolving each setting from an explicit value,
  then Rails credentials under `fopost:`, then the environment.
- A memoized, thread-safe `Fopost::Rails.client`.
- `rails generate fopost:install`, writing `config/initializers/fopost.rb`.
- `PublishJob` and `CreatePostJob`, re-enqueueing a rate-limited call for the interval the API
  asked for.
- A mountable engine that verifies incoming webhook signatures and republishes them as
  `ActiveSupport::Notifications` events.

[0.2.0]: https://github.com/fopost/fopost-rails/releases/tag/v0.2.0
[0.1.0]: https://github.com/fopost/fopost-rails/releases/tag/v0.1.0
