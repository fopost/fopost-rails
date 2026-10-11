# frozen_string_literal: true

require 'test_helper'

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  include FopostTestHelpers

  SECRET = 'whsec_a3f1c9d7e5b20418a3f1c9d7e5b20418'

  ARTICLE = {
    'id' => 'art_1',
    'title' => 'Best Trail Running Shoes 2026',
    'slug' => 'best-trail-running-shoes-2026',
    'excerpt' => 'Our picks.',
    'metaTitle' => nil,
    'metaDescription' => nil,
    'bodyMarkdown' => '# Shoes',
    'bodyHtml' => '<h1>Shoes</h1>',
    'featuredImage' => { 'mediaId' => 'med_1', 'url' => 'https://cdn.example/shoes.jpg', 'alt' => 'Shoes' },
    'images' => [],
    'tags' => %w[running gear],
    'keyword' => 'trail running shoes',
    'wordCount' => 1200,
    'publishedAt' => '2026-10-11T10:00:00.000Z',
    'publishedUrl' => 'https://yourbrand.com/blog/best-trail-running-shoes-2026'
  }.freeze

  def body(event, data = ARTICLE)
    JSON.generate('event' => event, 'data' => data, 'timestamp' => '2026-10-11T10:00:00.000Z')
  end

  def deliver(body, secret: SECRET, tamper: nil)
    timestamp = Time.now.to_i.to_s
    signed = Fopost::Webhooks.sign("#{timestamp}.#{body}", secret)
    post '/fopost/articles',
         params: tamper || body,
         headers: {
           'CONTENT_TYPE' => 'application/json',
           'X-FoPost-Signature' => Fopost::Webhooks.sign(body, secret),
           'X-FoPost-Signature-256' => signed,
           'X-FoPost-Timestamp' => timestamp,
           'X-FoPost-Event' => JSON.parse(body)['event'],
           'X-FoPost-Delivery' => 'delivery-1'
         }
  end

  def test_a_signed_test_delivery_is_accepted
    Fopost::Rails.config.website_secret = SECRET
    called = false
    Fopost::Rails.config.on_article_published = ->(_article) { called = true }

    deliver(body('article.test', {}))

    assert_response :ok
    assert_equal({ 'ok' => true }, response.parsed_body)
    refute called
  end

  def test_a_tampered_body_is_rejected_and_reaches_no_callback
    Fopost::Rails.config.website_secret = SECRET
    called = false
    Fopost::Rails.config.on_article_published = ->(_article) { called = true }

    deliver(body('article.published'), tamper: body('article.published', ARTICLE.merge('title' => 'Changed')))

    assert_response :unauthorized
    refute called
  end

  def test_a_published_article_reaches_the_callback_parsed_and_its_url_is_echoed
    Fopost::Rails.config.website_secret = SECRET
    received = nil
    notified = []
    subscriber = ActiveSupport::Notifications.subscribe('fopost.article.published') do |*, payload|
      notified << payload
    end
    Fopost::Rails.config.on_article_published = lambda do |article|
      received = article
      "https://yourbrand.com/blog/#{article.slug}"
    end

    deliver(body('article.published'))

    assert_response :ok
    assert_equal({ 'url' => 'https://yourbrand.com/blog/best-trail-running-shoes-2026' }, response.parsed_body)
    assert_instance_of Fopost::BlogArticlePublished, received
    assert_equal 'Best Trail Running Shoes 2026', received.title
    assert_equal 1200, received.word_count
    assert_equal 'Shoes', received.featured_image.alt
    assert_equal 1, notified.size
    assert_equal 'delivery-1', notified.first[:delivery_id]
    assert_same received, notified.first[:article]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def test_the_webhook_secret_is_the_fallback_and_no_secret_is_unavailable
    deliver(body('article.test', {}))

    assert_response :service_unavailable

    Fopost::Rails.config.webhook_secret = SECRET
    deliver(body('article.test', {}))

    assert_response :ok
  end
end
