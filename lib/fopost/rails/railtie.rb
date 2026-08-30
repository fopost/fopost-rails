# frozen_string_literal: true

require 'rails/railtie'

module Fopost
  module Rails
    # Registers `config.fopost`, so an app can set the SDK up from
    # `config/application.rb`:
    #
    #   config.fopost.api_key = Rails.application.credentials.dig(:fopost, :api_key)
    #
    # Nothing is loaded eagerly: the client is built on first use and the jobs
    # are autoloaded, so booting this gem costs a require of the SDK.
    class Railtie < ::Rails::Railtie
      config.fopost = Fopost::Rails.config

      # An initializer may have written settings after something already built a
      # client, so drop it once boot is done.
      config.after_initialize { Fopost::Rails.reset_client! }
    end
  end
end
