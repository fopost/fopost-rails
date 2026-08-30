# frozen_string_literal: true

require 'active_job'
require 'fopost/rails'

module Fopost
  module Rails
    # Base for the jobs this gem ships.
    #
    # A rate-limited call is re-enqueued for exactly as long as the API asked
    # for in `Retry-After`, instead of a guessed backoff.
    class ApplicationJob < ActiveJob::Base
      # The API never asks for longer than a minute; ignore it if it does.
      MAX_RETRY_WAIT = 60

      # ActiveJob hands the `wait:` proc the attempt count and nothing else, so
      # the seconds the API asked for ride along on the thread that raised.
      # `rescue_from` runs on that same thread, right after `perform`.
      RETRY_AFTER_KEY = :fopost_rails_retry_after

      queue_as { Fopost::Rails.config.queue_name }

      retry_on Fopost::RateLimitError,
               attempts: 5,
               wait: lambda { |executions|
                 asked = Thread.current[RETRY_AFTER_KEY]
                 Thread.current[RETRY_AFTER_KEY] = nil
                 seconds = asked.to_f
                 seconds.positive? ? [seconds, MAX_RETRY_WAIT].min.ceil : 2**executions
               }

      private

      def client
        Fopost::Rails.client
      end

      # Wrap every API call, so a 429 carries its interval into the retry.
      def with_retry_after
        yield
      rescue Fopost::RateLimitError => e
        Thread.current[RETRY_AFTER_KEY] = e.retry_after
        raise
      end
    end
  end
end
