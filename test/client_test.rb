# frozen_string_literal: true

require 'test_helper'

class ClientTest < ActiveSupport::TestCase
  include FopostTestHelpers

  def test_the_client_is_memoized
    assert_same Fopost::Rails.client, Fopost::Rails.client
  end

  def test_the_same_client_is_handed_to_every_thread
    Fopost::Rails.configure { |config| config.api_key = 'fp_explicit' }
    clients = Array.new(8) { Thread.new { Fopost::Rails.client } }.map(&:value)

    assert_equal 1, clients.uniq(&:object_id).size
  end

  def test_the_client_is_built_from_the_configuration
    Fopost::Rails.configure do |config|
      config.api_key = 'fp_explicit'
      config.base_url = 'https://api.test.fopost.com/v1'
    end

    assert_equal 'https://api.test.fopost.com/v1', Fopost::Rails.client.base_url
  end

  def test_configure_drops_a_client_built_from_older_settings
    first = Fopost::Rails.client
    Fopost::Rails.configure { |config| config.api_key = 'fp_rotated' }

    refute_same first, Fopost::Rails.client
  end

  def test_the_key_travels_on_every_request
    Fopost::Rails.configure { |config| config.api_key = 'fp_explicit' }
    Fopost::Rails.client = Fopost::Client.new(api_key: 'fp_explicit', transport: transport)
    transport.stub(:get, '/workspaces', json: { 'data' => [] })
    Fopost::Rails.client.workspaces.list

    assert_equal 'fp_explicit', transport.last.headers['X-API-Key']
  end

  def test_a_client_can_be_swapped_in
    fake = Object.new
    Fopost::Rails.client = fake

    assert_same fake, Fopost::Rails.client
  end
end
