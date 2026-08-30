# frozen_string_literal: true

require 'test_helper'

class ConfigurationTest < ActiveSupport::TestCase
  include FopostTestHelpers

  def config
    Fopost::Rails.config
  end

  def test_explicit_beats_credentials_and_the_environment
    ENV['FOPOST_API_KEY'] = 'fp_from_env'
    config.api_key = 'fp_explicit'

    assert_equal 'fp_explicit', config.api_key
  end

  def test_credentials_beat_the_environment
    ENV['FOPOST_API_KEY'] = 'fp_from_env'

    assert_equal 'fp_from_credentials', config.api_key
    assert_equal 'ws_from_credentials', config.default_workspace_id
  end

  def test_the_environment_answers_what_credentials_do_not_carry
    ENV['FOPOST_BASE_URL'] = 'https://api.test.fopost.com/v1'
    ENV['FOPOST_WEBHOOK_SECRET'] = 'whsec_from_env'

    assert_equal 'https://api.test.fopost.com/v1', config.base_url
    assert_equal 'whsec_from_env', config.webhook_secret
  end

  def test_defaults_apply_when_nothing_is_set
    assert_equal Fopost::Client::DEFAULT_BASE_URL, config.base_url
    assert_in_delta 30.0, config.timeout
    assert_equal 3, config.max_retries
    assert_equal 'default', config.queue_name
    assert_nil config.webhook_secret
  end

  def test_numeric_settings_are_cast_from_the_environment
    ENV['FOPOST_TIMEOUT'] = '5.5'
    ENV['FOPOST_MAX_RETRIES'] = '7'

    assert_in_delta 5.5, config.timeout
    assert_equal 7, config.max_retries
  end

  def test_an_empty_environment_variable_is_not_a_value
    ENV['FOPOST_WEBHOOK_SECRET'] = ''

    assert_nil config.webhook_secret
  end

  def test_the_railtie_exposes_the_same_object_as_config_fopost
    assert_same Fopost::Rails.config, ::Rails.application.config.fopost
  end

  def test_inspect_masks_the_secrets
    config.api_key = 'fp_supersecretvalue'
    config.webhook_secret = 'whsec_supersecretvalue'

    refute_includes config.inspect, 'supersecretvalue'
    assert_includes config.inspect, 'fp_s'
  end
end
