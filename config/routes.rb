# frozen_string_literal: true

Fopost::Rails::Engine.routes.draw do
  post '/webhooks', to: 'webhooks#create', as: :webhooks

  # So mounting straight onto the endpoint path also works:
  #   mount Fopost::Rails::Engine => '/fopost/webhooks'
  post '/', to: 'webhooks#create', as: :root
end
