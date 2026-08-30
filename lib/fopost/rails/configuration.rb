# frozen_string_literal: true

require 'fopost'

module Fopost
  module Rails
    # Settings for the API client, the jobs, and the webhook endpoint.
    #
    # Every setting resolves the same way: what you set explicitly wins, then
    # Rails credentials under `fopost:`, then the environment, then a default.
    #
    #   Fopost::Rails.configure do |config|
    #     config.api_key = 'fp_...'
    #     config.default_workspace_id = 'ws_...'
    #   end
    class Configuration
      SETTINGS = %i[
        api_key base_url timeout max_retries default_workspace_id webhook_secret queue_name
      ].freeze

      ENV_KEYS = {
        api_key: 'FOPOST_API_KEY',
        base_url: 'FOPOST_BASE_URL',
        timeout: 'FOPOST_TIMEOUT',
        max_retries: 'FOPOST_MAX_RETRIES',
        default_workspace_id: 'FOPOST_WORKSPACE_ID',
        webhook_secret: 'FOPOST_WEBHOOK_SECRET',
        queue_name: 'FOPOST_QUEUE'
      }.freeze

      DEFAULTS = {
        base_url: Fopost::Client::DEFAULT_BASE_URL,
        timeout: 30.0,
        max_retries: 3,
        queue_name: 'default'
      }.freeze

      attr_writer(*SETTINGS)

      def api_key
        resolve(:api_key)
      end

      def base_url
        resolve(:base_url)
      end

      def timeout
        value = resolve(:timeout)
        value&.to_f
      end

      def max_retries
        value = resolve(:max_retries)
        value&.to_i
      end

      def default_workspace_id
        resolve(:default_workspace_id)
      end

      # Shown once, when the webhook is created. The mounted endpoint needs it
      # to verify the signature FoPost sends.
      def webhook_secret
        resolve(:webhook_secret)
      end

      def queue_name
        resolve(:queue_name)
      end

      # The `fopost:` section of Rails credentials, or an empty hash outside a
      # booted app. A missing master key is treated as "no credentials" rather
      # than an error, so a machine without the key still boots.
      def credentials
        app = defined?(::Rails) && ::Rails.respond_to?(:application) ? ::Rails.application : nil
        section = app&.credentials&.fopost
        section.respond_to?(:[]) ? section : {}
      rescue StandardError
        {}
      end

      # Drop every explicit value, so the next read falls back again.
      def reset!
        SETTINGS.each { |key| instance_variable_set(:"@#{key}", nil) }
        self
      end

      def to_h
        SETTINGS.to_h { |key| [key, public_send(key)] }
      end

      # Keeps the key out of logs and consoles.
      def inspect
        redacted = to_h.merge(api_key: mask(api_key), webhook_secret: mask(webhook_secret))
        "#<Fopost::Rails::Configuration #{redacted.map { |k, v| "#{k}=#{v.inspect}" }.join(' ')}>"
      end

      private

      def resolve(key)
        explicit = instance_variable_get(:"@#{key}")
        return explicit unless explicit.nil?

        from_credentials = credentials[key]
        return from_credentials unless from_credentials.nil?

        from_env = ENV[ENV_KEYS.fetch(key)]
        return from_env unless from_env.nil? || from_env.empty?

        DEFAULTS[key]
      end

      def mask(value)
        value.nil? || value.empty? ? value : "#{value[0, 4]}…"
      end
    end
  end
end
