# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## What This Is

`fopost-rails` on RubyGems — the official Rails integration for the FoPost API. It is a **thin
wrapper** around the `fopost` gem (sibling repo `fopost-ruby`, module `Fopost`), which owns every
HTTP call, retry, model, and error class.

**Nothing about the API belongs here.** No transport, no endpoint paths, no response parsing, no
retry policy, no error mapping. If a change would touch any of those, it belongs in `fopost-ruby`.
What lives here is Rails wiring and only Rails wiring: configuration, a memoized client, a
generator, ActiveJob jobs, and a mountable webhook endpoint.

## Brand Rules

- The product is **FoPost** (`fopost.com`). Never write "OwlStack" — retired Aug 2026.
- Never write an email address. Support is https://fopost.com/contact and GitHub issues.
- Never name AI providers/models, infrastructure vendors, or any person.

## Architecture

```
lib/fopost-rails.rb                     require shim, matches the gem name
lib/fopost/rails.rb                     module entry: config, client, autoloads
lib/fopost/rails/configuration.rb       settings and their fallback order
lib/fopost/rails/railtie.rb             registers config.fopost
lib/fopost/rails/engine.rb              mountable engine (webhooks)
lib/fopost/rails/webhook_signature.rb   HMAC-SHA256 verification
lib/fopost/rails/application_job.rb     job base: rate-limit retry
lib/fopost/rails/publish_job.rb         PublishJob
lib/fopost/rails/create_post_job.rb     CreatePostJob
lib/generators/fopost/install/          rails generate fopost:install
app/controllers/fopost/rails/webhooks_controller.rb
config/routes.rb                        the engine's own routes
```

`Fopost::Rails.client` memoizes one `Fopost::Client` behind a `Mutex`. `configure` and
`reset_client!` drop it; `client=` swaps one in for tests. The jobs are `autoload`ed and each
requires `active_job` itself, so an app that never enqueues never pays for it. The railtie loads
only if `::Rails::Railtie` is defined, so `require 'fopost/rails'` works outside Rails too.

**`Rails` means `Fopost::Rails` inside this gem.** Always write `::Rails` for the framework —
`::Rails::Engine`, `::Rails::Generators::Base`, `::Rails.application`. `Style/RedundantConstantBase`
is disabled so this stays consistent even where the parser would resolve it anyway.

### Configuration order

Explicit value → Rails credentials `fopost:` → `ENV` → default. `Configuration#resolve` is the one
place this happens; adding a setting means an entry in `SETTINGS`, `ENV_KEYS`, and (if it has one)
`DEFAULTS`, plus a reader. `credentials` swallows a missing master key on purpose, so a machine
without the key still boots.

### Webhook signature — do not guess this

The API signs webhooks in `fopost/apps/api/src/services/webhook-dispatcher.ts` (`signPayload`) and
sends them in `fopost/apps/api/src/workers/webhook-worker.ts`:

- `X-FoPost-Signature: sha256=<hex>` where `<hex>` is `HMAC-SHA256(raw JSON body, webhook secret)`
- `X-FoPost-Event: <event>` · `X-FoPost-Delivery: <job id>`
- Body: `{"event": …, "data": …, "timestamp": …}`
- The secret is 32 random bytes as hex, returned **once** from `POST /v1/webhooks`

Verify over `request.raw_post` — a parsed-and-re-serialized hash will not match — and compare with
`ActiveSupport::SecurityUtils.secure_compare`. `WebhookSignature.sign` is public so app tests can
sign a request. If the API's scheme ever changes, this gem changes with it; never invent one.

Events: `post.published`, `post.failed`, `post.partially_failed`, `delivery.published`,
`delivery.failed`, `delivery.delayed`, `account.health_changed`.

### Rate-limit retries

`ActiveJob`'s `retry_on` hands its `wait:` proc the attempt count and nothing else, so
`ApplicationJob#with_retry_after` parks `RateLimitError#retry_after` on the current thread and the
proc reads it there. `rescue_from` runs on the same thread as `perform`, right after it. Wrap every
API call in a job with `with_retry_after`.

## API Contract

Owned by the `fopost` gem, repeated here only so a change is recognised as belonging there:
`X-API-Key` header (not Bearer), base URL `https://api.fopost.com/v1`, 30s timeout, 3 attempts
retrying `429`/`5xx` with `Retry-After` honoured, `{"data": …}` success envelope and
`{"error": …, "message": …}` errors.

## Parent dependency

`fopost` is on RubyGems. The gemspec declares the normal released coordinate
(`add_dependency 'fopost', '~> 0.1'`), which resolves from RubyGems. The `Gemfile` and every
`gemfiles/*.gemfile` still resolve it from source:

```ruby
gem 'fopost', github: 'fopost/fopost-ruby'
```

Those lines are a leftover and no longer needed now that the parent is published; the gemspec
needs no change. The release workflow's "Smoke test the entry point" step still loads the gem under
`bundle exec` rather than installing the built gem; that workaround is no longer needed either.

## Commands

```bash
bundle install
bundle exec rake test                      # minitest, fully offline
bundle exec rake test TEST=test/jobs_test.rb
bundle exec rubocop
bundle exec rake                           # test + rubocop
BUNDLE_GEMFILE=gemfiles/rails_7_1.gemfile bundle exec rake test
```

Tests boot a real `::Rails::Application` (`DummyApp` in `test/test_helper.rb`) rooted at
`test/dummy`, with real encrypted credentials generated at test time — the precedence tests go
through the same lookup a booted app uses, not a stub. Because the app class is defined from
`test_helper.rb`, Rails derives the credential paths from the gem root, so they are pointed back at
the dummy explicitly. `StubTransport` answers every request; nothing reaches the network.

## Conventions

- Prettier equivalents: rubocop with `.rubocop.yml` (120 char lines, `Metrics` off).
- Comments short, only where a "why" is non-obvious. Public API gets a doc comment; obvious code
  gets none.
- New capability → a job or a config setting, plus a test that fails when the code is inverted.
- Never reimplement something the SDK already does. Reach for `Fopost::Rails.client` instead.

## Releasing

Tag `v<version>` matching `lib/fopost/rails/version.rb`; `.github/workflows/release.yml` publishes
to RubyGems.

Publishing uses **RubyGems trusted publishing (OIDC)** — no API key secret. Set it up once on
rubygems.org before the first tag:

1. Sign in, go to the gem's page → **Trusted publishers** → **Create**. For a gem that does not
   exist yet, use **Profile → Trusted publishers → Create** and name the gem there.
2. Provider **GitHub Actions**; repository owner `fopost`, repository name `fopost-rails`,
   workflow filename `release.yml`, environment `rubygems`.
3. In this repo, create the `rubygems` environment (Settings → Environments) and add whatever
   reviewers you want gating a release.

The workflow already requests `id-token: write` and uses `rubygems/release-gem@v1`. If trusted
publishing is ever swapped for a key, the secret to add is `RUBYGEMS_API_KEY` and the push step
becomes `gem push` with `~/.gem/credentials` written from it.

## Git

Conventional Commits, atomic. Branch `feature/<description>`, merge to `main` via PR.
Never `gh pr create` — push the branch and hand over the compare link.
