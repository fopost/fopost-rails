# Examples

Drop-in snippets for a Rails app that already has the gem installed and
`rails generate fopost:install` run.

| File | Where it goes |
| --- | --- |
| `initializer.rb` | `config/initializers/fopost.rb` |
| `posts_controller.rb` | `app/controllers/posts_controller.rb` |
| `webhook_subscriber.rb` | `config/initializers/fopost_webhooks.rb` |

To receive webhooks, mount the engine in `config/routes.rb`:

```ruby
mount Fopost::Rails::Engine => '/fopost'
```

then create a webhook pointing at `https://your-app.example/fopost/webhooks` and
put the secret it shows you once into `config.webhook_secret`.
