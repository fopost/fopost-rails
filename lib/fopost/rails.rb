# frozen_string_literal: true

require 'fopost'

require 'fopost/rails/version'
require 'fopost/rails/configuration'

# Official Rails integration for the FoPost API.
#
# This gem is a thin wrapper: every request, retry, model, and error class
# lives in the `fopost` gem. What is added here is Rails wiring — configuration
# and credentials, a memoized client, an install generator, ActiveJob jobs, and
# a mountable endpoint for receiving webhooks.
#
#   Fopost::Rails.client.posts.list(status: 'scheduled')
#   Fopost::Rails::PublishJob.perform_later(post.id)
module Fopost
  module Rails
    # Loaded on first use, so an app that never enqueues a job never pulls
    # ActiveJob in on our account, and requiring this gem stays cheap.
    autoload :ApplicationJob, 'fopost/rails/application_job'
    autoload :CreatePostJob, 'fopost/rails/create_post_job'
    autoload :PublishJob, 'fopost/rails/publish_job'
    autoload :WebhookSignature, 'fopost/rails/webhook_signature'

    @mutex = Mutex.new
    @client = nil
    @config = nil

    class << self
      # The settings object. Also reachable as `config.fopost` inside
      # `config/application.rb` and any Rails initializer.
      def config
        @config ||= Configuration.new
      end
      alias configuration config

      #   Fopost::Rails.configure do |c|
      #     c.api_key = ENV['FOPOST_API_KEY']
      #   end
      def configure
        yield config
        reset_client!
        config
      end

      # A memoized, configured Fopost::Client. Safe to call from any thread.
      def client
        @client || @mutex.synchronize { @client ||= build_client }
      end

      # Swap in your own client — a stubbed transport in tests, say.
      def client=(client)
        @mutex.synchronize { @client = client }
      end

      # Forget the memoized client, so the next call rebuilds it from config.
      def reset_client!
        @mutex.synchronize { @client = nil }
        nil
      end

      # Config and client back to their defaults. Meant for test suites.
      def reset!
        reset_client!
        config.reset!
        nil
      end

      private

      def build_client
        Fopost::Client.new(
          api_key: config.api_key,
          base_url: config.base_url,
          timeout: config.timeout,
          max_retries: config.max_retries
        )
      end
    end
  end
end

require 'fopost/rails/railtie' if defined?(::Rails::Railtie)
require 'fopost/rails/engine' if defined?(::Rails::Engine)
