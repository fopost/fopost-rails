# frozen_string_literal: true

require 'test_helper'

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  include FopostTestHelpers

  SECRET = 'a3f1c9d7e5b20418a3f1c9d7e5b20418a3f1c9d7e5b20418a3f1c9d7e5b20418'

  BODY = JSON.generate(
    'event' => 'post.published',
    'data' => { 'postId' => 'post_1', 'workspaceId' => 'ws_1' },
    'timestamp' => '2026-08-30T10:00:00.000Z'
  )

  def deliver(body: BODY, signature: nil, event: 'post.published', delivery: 'webhook-1-post.published-1')
    signature ||= Fopost::Rails::WebhookSignature.sign(body, SECRET)
    post '/fopost/webhooks',
         params: body,
         headers: {
           'CONTENT_TYPE' => 'application/json',
           'X-FoPost-Signature' => signature,
           'X-FoPost-Event' => event,
           'X-FoPost-Delivery' => delivery
         }
  end

  def test_a_valid_delivery_is_accepted_and_published
    Fopost::Rails.config.webhook_secret = SECRET
    received = []
    subscriber = ActiveSupport::Notifications.subscribe('fopost.post.published') do |*, payload|
      received << payload
    end

    deliver

    assert_response :ok
    assert_equal 1, received.size
    assert_equal 'post.published', received.first[:event]
    assert_equal({ 'postId' => 'post_1', 'workspaceId' => 'ws_1' }, received.first[:data])
    assert_equal 'webhook-1-post.published-1', received.first[:delivery_id]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def test_every_delivery_also_reaches_the_catch_all
    Fopost::Rails.config.webhook_secret = SECRET
    events = []
    subscriber = ActiveSupport::Notifications.subscribe('fopost.webhook') do |*, payload|
      events << payload[:event]
    end

    deliver

    assert_equal ['post.published'], events
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def test_a_bad_signature_is_rejected_and_publishes_nothing
    Fopost::Rails.config.webhook_secret = SECRET
    received = []
    subscriber = ActiveSupport::Notifications.subscribe('fopost.webhook') { received << 1 }

    deliver(signature: 'sha256=0000000000000000000000000000000000000000000000000000000000000000')

    assert_response :unauthorized
    assert_empty received
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def test_a_signature_over_a_different_body_is_rejected
    Fopost::Rails.config.webhook_secret = SECRET

    deliver(signature: Fopost::Rails::WebhookSignature.sign('{"event":"post.failed"}', SECRET))

    assert_response :unauthorized
  end

  def test_a_delivery_with_no_signature_is_rejected
    Fopost::Rails.config.webhook_secret = SECRET

    post '/fopost/webhooks', params: BODY, headers: { 'CONTENT_TYPE' => 'application/json' }

    assert_response :unauthorized
  end

  def test_an_unconfigured_secret_refuses_to_pretend
    deliver

    assert_response :service_unavailable
  end

  def test_a_signed_but_unreadable_body_is_a_bad_request
    Fopost::Rails.config.webhook_secret = SECRET

    deliver(body: 'not json')

    assert_response :bad_request
  end

  def test_a_signed_body_with_no_event_is_a_bad_request
    Fopost::Rails.config.webhook_secret = SECRET

    deliver(body: JSON.generate('data' => {}))

    assert_response :bad_request
  end
end
