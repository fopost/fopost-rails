# frozen_string_literal: true

# app/controllers/posts_controller.rb
#
# Reads go straight through the client. Writes that reach a social platform go
# on a queue, so a slow platform never holds a request open.
class PostsController < ApplicationController
  def index
    @posts = Fopost::Rails.client.posts.list(status: 'scheduled')
  end

  # Compose now, deliver in the background.
  def create
    Fopost::Rails::CreatePostJob.perform_later(
      content: params.require(:text),
      accounts: params.require(:account_ids),
      publish: true
    )

    redirect_to posts_path, notice: 'Queued for publishing.'
  end

  # Schedule for later, straight through the API.
  def schedule
    post = Fopost::Rails.client.posts.create(
      workspace_id: Fopost::Rails.config.default_workspace_id,
      content: params.require(:text),
      accounts: params.require(:account_ids),
      status: 'scheduled',
      schedule_at: 1.hour.from_now
    )

    redirect_to posts_path, notice: "Scheduled #{post.id}."
  end

  # Publish something that already exists.
  def publish
    Fopost::Rails::PublishJob.perform_later(params.require(:id))
    head :accepted
  end

  rescue_from Fopost::PaymentRequiredError do |error|
    redirect_to error.upgrade_url || root_path, alert: error.message
  end

  rescue_from Fopost::Error do |error|
    Rails.logger.error("FoPost: #{error}")
    head :bad_gateway
  end
end
