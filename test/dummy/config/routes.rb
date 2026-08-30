# frozen_string_literal: true

Rails.application.routes.draw do
  mount Fopost::Rails::Engine => '/fopost'
end
