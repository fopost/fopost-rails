# FoPost for Rails

[![Gem Version](https://img.shields.io/gem/v/fopost-rails.svg)](https://rubygems.org/gems/fopost-rails)
[![Downloads](https://img.shields.io/gem/dt/fopost-rails.svg)](https://rubygems.org/gems/fopost-rails)
[![CI](https://img.shields.io/github/actions/workflow/status/fopost/fopost-rails/ci.yml?branch=main&label=ci)](https://github.com/fopost/fopost-rails/actions)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

The official Rails integration for the [FoPost](https://fopost.com) API. Connect social accounts
once, then compose, schedule, and publish to +30 platforms from your own application.

This gem is a thin wrapper around the [`fopost`](https://github.com/fopost/fopost-ruby) gem. Every
request, retry, model, and error class lives there; what is added here is Rails wiring:

- `config.fopost` and Rails credentials, with a sensible fallback order
- a memoized, thread-safe `Fopost::Rails.client`
- `rails generate fopost:install`
- ActiveJob jobs, so publishing never blocks a request
- a mountable endpoint that verifies and republishes incoming FoPost webhooks

Requires Ruby 3.1+ and Rails 7.0+.

> **0.x release.** The public API is still settling and minor versions may contain breaking
> changes. Pin an exact version if that matters to you.

## Install

```bash
bundle add fopost-rails
```

Then write the initializer:

```bash
bin/rails generate fopost:install
```

## Configure

Create an API key at [fopost.com/dashboard/api-keys](https://fopost.com/dashboard/api-keys) and put it
somewhere the app can read it:

```bash
bin/rails credentials:edit
```

```yaml
fopost:
  api_key: fp_your_key_here
  default_workspace_id: ws_...
  webhook_secret: whsec_...
```

Or in the environment:

```dotenv
FOPOST_API_KEY=fp_your_key_here
```

Every setting resolves the same way — **what you set explicitly wins, then Rails credentials under
`fopost:`, then the environment, then the default**:

| Setting | Credentials key | Environment | Default |
| --- | --- | --- | --- |
| `api_key` | `fopost: api_key:` | `FOPOST_API_KEY` | none, required |
| `base_url` | `base_url` | `FOPOST_BASE_URL` | `https://api.fopost.com/v1` |
| `timeout` | `timeout` | `FOPOST_TIMEOUT` | `30.0` |
| `max_retries` | `max_retries` | `FOPOST_MAX_RETRIES` | `3` |
| `default_workspace_id` | `default_workspace_id` | `FOPOST_WORKSPACE_ID` | none |
| `webhook_secret` | `webhook_secret` | `FOPOST_WEBHOOK_SECRET` | none |
| `queue_name` | `queue_name` | `FOPOST_QUEUE` | `default` |

Set them in the initializer:

```ruby
Fopost::Rails.configure do |config|
  config.api_key = Rails.application.credentials.dig(:fopost, :api_key)
  config.queue_name = 'social'
end
```

or from `config/application.rb`:

```ruby
config.fopost.default_workspace_id = 'ws_...'
```

## Publishing from a controller

`Fopost::Rails.client` is a configured `Fopost::Client`, memoized and safe to call from any
thread. The [`fopost` gem README](https://github.com/fopost/fopost-ruby) documents the full
resource surface — `posts`, `accounts`, `workspaces`, `labels`, `ai`, `inbox`, `ads`.

```ruby
class PostsController < ApplicationController
  def index
    @posts = Fopost::Rails.client.posts.list(status: 'scheduled')
  end

  def create
    post = Fopost::Rails.client.posts.create(
      workspace_id: Fopost::Rails.config.default_workspace_id,
      content: params.require(:text),
      accounts: params.require(:account_ids)
    )

    Fopost::Rails::PublishJob.perform_later(post.id)
    redirect_to posts_path, notice: 'Queued for publishing.'
  end
end
```

Errors are the SDK's, so one `rescue_from` covers the lot:

```ruby
rescue_from Fopost::PaymentRequiredError do |error|
  redirect_to error.upgrade_url, alert: error.message
end

rescue_from Fopost::Error do |error|
  Rails.logger.error("FoPost: #{error}")   # "[404 (not_found)] Post not found"
  head :bad_gateway
end
```

## Background jobs

Publishing reaches a third-party network, so it belongs off the request cycle.

```ruby
# Publish something that already exists.
Fopost::Rails::PublishJob.perform_later(post.id)

# Compose and, optionally, send in one job.
Fopost::Rails::CreatePostJob.perform_later(
  content: 'Shipping today.',
  accounts: account_ids,
  publish: true
)

# Or schedule it, and pass anything else the SDK takes through `options`.
Fopost::Rails::CreatePostJob.perform_later(
  workspace_id: 'ws_...',
  content: ['First post in the thread', 'And the reply'],
  accounts: account_ids,
  status: 'scheduled',
  schedule_at: 1.hour.from_now,
  options: { labels: ['launch'], title: 'Launch week' }
)
```

`workspace_id` falls back to `config.default_workspace_id`. Both jobs run on `config.queue_name`.

When the API answers `429`, the job is re-enqueued for exactly the interval the API asked for in
`Retry-After` (capped at a minute), up to five attempts. Every other `Fopost::Error` is left to
your queue's own error handling.

Publishing returns once delivery is **queued**, not once it is live. Subscribe to
`fopost.post.published` for that.

## Receiving webhooks

Mount the engine:

```ruby
# config/routes.rb
mount Fopost::Rails::Engine => '/fopost'
```

That serves `POST /fopost/webhooks`. Create a webhook pointing at it, copy the secret it shows you
once into `config.webhook_secret`, and subscribe:

```ruby
# config/initializers/fopost_webhooks.rb
ActiveSupport::Notifications.subscribe('fopost.post.published') do |*, payload|
  payload[:event]        # "post.published"
  payload[:data]         # the event body FoPost sent
  payload[:timestamp]    # ISO 8601, when FoPost sent it
  payload[:delivery_id]  # X-FoPost-Delivery, unique per attempt
  payload[:payload]      # the whole parsed body
end
```

Two notifications fire per verified delivery: `fopost.<event>` and `fopost.webhook` for a
catch-all. The events FoPost sends are `post.published`, `post.failed`, `post.partially_failed`,
`delivery.published`, `delivery.failed`, `delivery.delayed`, and `account.health_changed`.

Verification is not optional and not yours to write. FoPost signs the exact bytes of the request
body with HMAC-SHA256, keyed by the webhook secret, and sends the hex digest as
`X-FoPost-Signature: sha256=<digest>`. The controller recomputes it over the raw body and compares
in constant time; a mismatch is a `401` and publishes nothing, and an unconfigured secret is a
`503` rather than a pretended success.

To sign a request yourself — in a request spec, say:

```ruby
body = { event: 'post.published', data: { postId: 'post_1' } }.to_json

post '/fopost/webhooks',
     params: body,
     headers: {
       'CONTENT_TYPE' => 'application/json',
       'X-FoPost-Signature' => Fopost::Rails::WebhookSignature.sign(body, secret)
     }
```

## Testing your app

Swap the client for one wired to your own transport and nothing touches the network:

```ruby
Fopost::Rails.client = Fopost::Client.new(api_key: 'fp_test', transport: my_stub)
```

`Fopost::Rails.reset!` puts config and client back to their defaults between tests.

## Looking for the free self-hosted toolkit?

This gem talks to the FoPost Cloud API with a FoPost API key. To publish straight to the social
platforms using your own app credentials, with no FoPost account involved, use
[`fopost-social-core`](https://github.com/fopost/fopost-social-core) instead. The two families are
separate on purpose and never depend on each other.

## Links

- Documentation: [fopost.com/docs](https://fopost.com/docs)
- API keys: [fopost.com/dashboard/api-keys](https://fopost.com/dashboard/api-keys)
- The SDK this wraps: [`fopost`](https://github.com/fopost/fopost-ruby)
- Issues: [github.com/fopost/fopost-rails/issues](https://github.com/fopost/fopost-rails/issues)
- Support: [fopost.com/contact](https://fopost.com/contact)

## License

MIT. Copyright (c) 2026 Porter Bridge, LLC. See [LICENSE](LICENSE).
