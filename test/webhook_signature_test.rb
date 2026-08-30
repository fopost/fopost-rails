# frozen_string_literal: true

require 'test_helper'

class WebhookSignatureTest < ActiveSupport::TestCase
  PAYLOAD = '{"event":"post.published","data":{"id":"post_1"},"timestamp":"2026-08-30T10:00:00.000Z"}'
  SECRET = 'a3f1c9d7e5b20418a3f1c9d7e5b20418a3f1c9d7e5b20418a3f1c9d7e5b20418'

  # Pinned against the API's own signer: HMAC-SHA256 over the raw body, hex,
  # behind a `sha256=` prefix.
  def test_the_signature_matches_the_scheme_the_api_uses
    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', SECRET, PAYLOAD)}"

    assert_equal expected, Fopost::Rails::WebhookSignature.sign(PAYLOAD, SECRET)
  end

  def test_a_matching_signature_is_valid
    signature = Fopost::Rails::WebhookSignature.sign(PAYLOAD, SECRET)

    assert Fopost::Rails::WebhookSignature.valid?(PAYLOAD, signature, SECRET)
  end

  def test_a_signature_from_another_secret_is_rejected
    signature = Fopost::Rails::WebhookSignature.sign(PAYLOAD, 'another_secret')

    refute Fopost::Rails::WebhookSignature.valid?(PAYLOAD, signature, SECRET)
  end

  def test_a_changed_body_is_rejected
    signature = Fopost::Rails::WebhookSignature.sign(PAYLOAD, SECRET)

    refute Fopost::Rails::WebhookSignature.valid?("#{PAYLOAD} ", signature, SECRET)
  end

  def test_a_missing_signature_or_secret_is_rejected
    refute Fopost::Rails::WebhookSignature.valid?(PAYLOAD, nil, SECRET)
    refute Fopost::Rails::WebhookSignature.valid?(PAYLOAD, 'sha256=abc', nil)
    refute Fopost::Rails::WebhookSignature.valid?(PAYLOAD, 'sha256=abc', '')
  end

  def test_a_signature_without_the_prefix_is_rejected
    hex = OpenSSL::HMAC.hexdigest('SHA256', SECRET, PAYLOAD)

    refute Fopost::Rails::WebhookSignature.valid?(PAYLOAD, hex, SECRET)
  end
end
