# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class JobsTest < ActiveSupport::TestCase
  include FopostTestHelpers
  include ActiveJob::TestHelper

  def test_publish_job_enqueues
    assert_enqueued_with(job: Fopost::Rails::PublishJob, args: ['post_1']) do
      Fopost::Rails::PublishJob.perform_later('post_1')
    end
  end

  def test_publish_job_lands_on_the_configured_queue
    Fopost::Rails.configure { |config| config.queue_name = 'social' }

    assert_enqueued_with(job: Fopost::Rails::PublishJob, queue: 'social') do
      Fopost::Rails::PublishJob.perform_later('post_1')
    end
  end

  def test_publish_job_calls_the_api
    stub_client
    transport.stub(:post, '/posts/post_1/publish', json: { 'data' => { 'status' => 'queued' } })

    Fopost::Rails::PublishJob.perform_now('post_1')

    assert_equal '/posts/post_1/publish', resource_path(transport.last.path)
  end

  def test_create_post_job_creates_and_can_publish
    stub_client
    transport.stub(:post, '/posts', json: { 'data' => POST_FIXTURE })
    transport.stub(:post, '/posts/post_1/publish', json: { 'data' => { 'status' => 'queued' } })
    Fopost::Rails.config.default_workspace_id = 'ws_default'

    post_id = Fopost::Rails::CreatePostJob.perform_now(
      content: 'Hello from Rails', accounts: ['acc_1'], publish: true
    )

    assert_equal 'post_1', post_id
    created = transport.calls.first.json

    assert_equal 'ws_default', created['workspace_id']
    assert_equal [{ 'text' => 'Hello from Rails' }], created['content']
    assert_equal ['acc_1'], created['accounts']
    assert_equal '/posts/post_1/publish', resource_path(transport.last.path)
  end

  def test_create_post_job_needs_a_workspace
    stub_client

    # No explicit workspace, no credentials, no environment.
    Fopost::Rails.config.stub(:credentials, {}) do
      assert_raises(ArgumentError) do
        Fopost::Rails::CreatePostJob.perform_now(content: 'Hi', accounts: ['acc_1'])
      end
    end
  end

  def test_a_rate_limited_job_is_re_enqueued_for_as_long_as_the_api_asked
    stub_client
    transport.stub(
      :post, '/posts/post_1/publish',
      status: 429,
      json: { 'error' => 'rate_limited', 'message' => 'Too many requests' },
      headers: { 'retry-after' => '12' }
    )

    Fopost::Rails::PublishJob.perform_now('post_1')

    assert_equal 1, enqueued_jobs.size
    at = enqueued_jobs.first['at'] || enqueued_jobs.first[:at]

    assert_in_delta Time.now.to_f + 12, at, 5
  end

  def test_a_rate_limit_with_no_interval_backs_off_on_its_own
    stub_client
    transport.stub(
      :post, '/posts/post_1/publish',
      status: 429,
      json: { 'error' => 'rate_limited', 'message' => 'Too many requests' }
    )

    Fopost::Rails::PublishJob.perform_now('post_1')

    at = enqueued_jobs.first['at'] || enqueued_jobs.first[:at]

    assert_operator at, :>, Time.now.to_f
  end

  def test_other_api_errors_are_not_swallowed
    stub_client
    transport.stub(
      :post, '/posts/post_1/publish',
      status: 404, json: { 'error' => 'not_found', 'message' => 'Post not found' }
    )

    assert_raises(Fopost::NotFoundError) { Fopost::Rails::PublishJob.perform_now('post_1') }
    assert_empty enqueued_jobs
  end
end
