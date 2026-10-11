# frozen_string_literal: true

require 'json'
require 'active_support/notifications'

module Fopost
  module Rails
    # Receives the blog's website target: FoPost posts here when an article is
    # published. The signature is verified by the `fopost` gem over the raw
    # body; a mismatch is a 401 and nothing runs.
    #
    #   # config/initializers/fopost.rb
    #   config.on_article_published = ->(article) { Article.import!(article).url }
    #
    # The callback may return the URL the article now lives at, which is
    # echoed back as `{ "url": ... }`. `fopost.article.published` also fires as
    # an ActiveSupport::Notifications event for subscribers.
    class ArticlesController < ActionController::API
      def create
        secret = Fopost::Rails.config.website_secret || Fopost::Rails.config.webhook_secret
        return head :service_unavailable if secret.nil? || secret.to_s.empty?

        event = Fopost::Webhooks.verify(request.raw_post, request.headers, secret)
        return render json: { ok: true } unless event.event == 'article.published'

        url = deliver(event)
        render json: url.is_a?(String) && !url.empty? ? { url: url } : { ok: true }
      rescue Fopost::WebhookSignatureError
        head :unauthorized
      end

      private

      def deliver(event)
        article = event.article
        notification = {
          event: event.event,
          article: article,
          data: event.data,
          timestamp: event.timestamp,
          delivery_id: request.headers[Fopost::Webhooks::DELIVERY_HEADER]
        }
        ActiveSupport::Notifications.instrument('fopost.article.published', notification)

        Fopost::Rails.config.on_article_published&.call(article)
      end
    end
  end
end
