# frozen_string_literal: true

# config/initializers/fopost.rb
#
# Anything left out falls back to Rails credentials under `fopost:`, then to
# the environment, so most apps set nothing here at all.
Fopost::Rails.configure do |config|
  config.api_key = Rails.application.credentials.dig(:fopost, :api_key)
  config.default_workspace_id = Rails.application.credentials.dig(:fopost, :workspace_id)
  config.webhook_secret = Rails.application.credentials.dig(:fopost, :webhook_secret)
  config.queue_name = 'social'
end
