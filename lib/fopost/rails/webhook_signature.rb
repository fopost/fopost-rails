# frozen_string_literal: true

require 'openssl'
require 'active_support/security_utils'

module Fopost
  module Rails
    # FoPost signs every webhook body with HMAC-SHA256 over the exact bytes it
    # sent, keyed by the webhook secret, and puts the hex digest in
    # `X-FoPost-Signature` behind a `sha256=` prefix.
    #
    # Verify against the raw request body — a parsed-and-re-serialized hash will
    # not match.
    module WebhookSignature
      SIGNATURE_HEADER = 'X-FoPost-Signature'
      EVENT_HEADER = 'X-FoPost-Event'
      DELIVERY_HEADER = 'X-FoPost-Delivery'
      PREFIX = 'sha256='

      # The header value FoPost would send for this body and secret.
      def self.sign(payload, secret)
        "#{PREFIX}#{OpenSSL::HMAC.hexdigest('SHA256', secret.to_s, payload.to_s)}"
      end

      # Constant-time comparison, so a wrong signature leaks no timing.
      def self.valid?(payload, signature, secret)
        return false if signature.nil? || secret.nil? || secret.to_s.empty?

        ActiveSupport::SecurityUtils.secure_compare(sign(payload, secret), signature.to_s)
      end
    end
  end
end
