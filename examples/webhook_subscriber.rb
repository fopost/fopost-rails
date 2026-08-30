# frozen_string_literal: true

# config/initializers/fopost_webhooks.rb
#
# Every verified delivery to the mounted endpoint becomes two notifications:
# `fopost.<event>` and `fopost.webhook` for a catch-all.
ActiveSupport::Notifications.subscribe('fopost.post.published') do |*, payload|
  Rails.logger.info("FoPost published post #{payload[:data]['postId']}")
end

ActiveSupport::Notifications.subscribe('fopost.delivery.failed') do |*, payload|
  Rails.logger.warn("FoPost delivery failed: #{payload[:data]}")
end

# One subscriber for the lot, if you would rather fan out yourself.
ActiveSupport::Notifications.subscribe('fopost.webhook') do |*, payload|
  WebhookLog.create!(
    event: payload[:event],
    delivery_id: payload[:delivery_id],
    occurred_at: payload[:timestamp],
    body: payload[:payload]
  )
end
