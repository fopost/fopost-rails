# frozen_string_literal: true

require 'fopost/rails/application_job'

module Fopost
  module Rails
    # Publish an existing post without blocking the request that asked for it.
    #
    #   Fopost::Rails::PublishJob.perform_later(post_id)
    #
    # Returns once the API has queued delivery, which is not the same as live:
    # subscribe to `fopost.post.published` for that.
    class PublishJob < ApplicationJob
      def perform(post_id)
        with_retry_after { client.posts.publish(post_id) }
      end
    end
  end
end
