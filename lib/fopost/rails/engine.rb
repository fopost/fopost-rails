# frozen_string_literal: true

require 'rails/engine'

module Fopost
  module Rails
    # Mount to receive FoPost webhooks:
    #
    #   # config/routes.rb
    #   mount Fopost::Rails::Engine => '/fopost'
    #
    # That serves `POST /fopost/webhooks`. Point a webhook at it, set
    # `config.webhook_secret` to the secret FoPost showed you once, and
    # subscribe to the events it publishes.
    class Engine < ::Rails::Engine
      isolate_namespace Fopost::Rails
    end
  end
end
