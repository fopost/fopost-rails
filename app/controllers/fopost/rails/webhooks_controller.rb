# frozen_string_literal: true

require 'json'
require 'active_support/notifications'
require 'fopost/rails/webhook_signature'

module Fopost
  module Rails
    # Receives FoPost webhooks and republishes them as
    # ActiveSupport::Notifications events, so subscribing costs no route,
    # controller, or queue of your own.
    #
    #   ActiveSupport::Notifications.subscribe('fopost.post.published') do |*, payload|
    #     Rails.logger.info(payload[:data])
    #   end
    #
    # Two events fire per delivery: `fopost.<event>` (`fopost.post.published`,
    # `fopost.delivery.failed`, …) and `fopost.webhook` for a catch-all.
    class WebhooksController < ActionController::API
      def create
        secret = Fopost::Rails.config.webhook_secret
        return head :service_unavailable if secret.nil? || secret.to_s.empty?

        payload = request.raw_post
        signature = request.headers[WebhookSignature::SIGNATURE_HEADER]
        return head :unauthorized unless WebhookSignature.valid?(payload, signature, secret)

        body = parse(payload)
        event = body && body['event']
        return head :bad_request unless event.is_a?(String) && !event.empty?

        publish(event, body)
        head :ok
      end

      private

      def publish(event, body)
        notification = {
          event: event,
          data: body['data'],
          timestamp: body['timestamp'],
          delivery_id: request.headers[WebhookSignature::DELIVERY_HEADER],
          payload: body
        }

        ActiveSupport::Notifications.instrument("fopost.#{event}", notification)
        ActiveSupport::Notifications.instrument('fopost.webhook', notification)
      end

      def parse(payload)
        parsed = JSON.parse(payload.to_s)
        parsed.is_a?(Hash) ? parsed : nil
      rescue JSON::ParserError
        nil
      end
    end
  end
end
