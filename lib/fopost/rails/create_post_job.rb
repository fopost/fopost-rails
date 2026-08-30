# frozen_string_literal: true

require 'fopost/rails/application_job'

module Fopost
  module Rails
    # Create a post — and optionally send it — off the request cycle.
    #
    #   Fopost::Rails::CreatePostJob.perform_later(
    #     content: 'Shipping today.',
    #     accounts: account_ids,
    #     publish: true
    #   )
    #
    # `workspace_id` falls back to `config.default_workspace_id`. `options` is
    # merged into the create call, so anything the SDK takes (`labels`,
    # `title`, `settings`, …) passes straight through.
    class CreatePostJob < ApplicationJob
      def perform(content:, accounts:, workspace_id: nil, status: 'draft', schedule_at: nil,
                  publish: false, options: {})
        workspace = workspace_id || Fopost::Rails.config.default_workspace_id
        if workspace.nil? || workspace.to_s.empty?
          raise ArgumentError,
                'fopost: pass workspace_id: or set config.default_workspace_id'
        end

        post = with_retry_after do
          client.posts.create(
            workspace_id: workspace,
            content: content,
            accounts: accounts,
            status: status,
            schedule_at: schedule_at,
            **(options || {}).transform_keys(&:to_sym)
          )
        end

        with_retry_after { client.posts.publish(post.id) } if publish

        post.id
      end
    end
  end
end
