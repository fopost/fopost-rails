# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'fileutils'
require 'json'
require 'logger'
require 'securerandom'
require 'yaml'

ENV['RAILS_ENV'] = 'test'

require 'rails'
require 'active_support/encrypted_configuration'
require 'action_controller/railtie'
require 'active_job/railtie'

DUMMY_ROOT = File.expand_path('dummy', __dir__)

# Real encrypted credentials, generated here so the precedence tests go through
# the same lookup a booted app uses rather than a stub.
CREDENTIALS = {
  'api_key' => 'fp_from_credentials',
  'default_workspace_id' => 'ws_from_credentials'
}.freeze

def write_dummy_credentials!
  FileUtils.mkdir_p(File.join(DUMMY_ROOT, 'config'))
  key_path = File.join(DUMMY_ROOT, 'config/master.key')
  content_path = File.join(DUMMY_ROOT, 'config/credentials.yml.enc')
  FileUtils.rm_f([key_path, content_path])
  File.write(key_path, ActiveSupport::EncryptedFile.generate_key)

  ActiveSupport::EncryptedConfiguration.new(
    config_path: content_path,
    key_path: key_path,
    env_key: 'FOPOST_RAILS_TEST_KEY',
    raise_if_missing_key: true
  ).write({ 'fopost' => CREDENTIALS }.to_yaml)
end

write_dummy_credentials!

require 'fopost/rails'

# The dummy app: just enough Rails to mount the engine and enqueue a job.
class DummyApp < ::Rails::Application
  config.root = DUMMY_ROOT
  # The app is defined from test_helper.rb, so Rails derives the credential
  # paths from the gem root; point them back at the dummy.
  config.credentials.content_path = File.join(DUMMY_ROOT, 'config/credentials.yml.enc')
  config.credentials.key_path = File.join(DUMMY_ROOT, 'config/master.key')
  config.eager_load = false
  config.secret_key_base = SecureRandom.hex(32)
  config.logger = Logger.new(IO::NULL)
  config.active_job.queue_adapter = :test
  config.hosts.clear
end

DummyApp.initialize!

require 'minitest/autorun'
require 'active_support/test_case'
require 'action_dispatch/testing/integration'
require 'active_job/test_helper'
require 'rails/generators'
require 'rails/generators/test_case'

ActionDispatch::IntegrationTest.app = DummyApp

# The parent SDK owns the version prefix on every request path. Tests match on
# the resource suffix so they survive the prefix moving.
API_VERSION_PREFIX = %r{\A(?:/api)?/v\d+}

# A transport that answers from a script instead of the network.
class StubTransport
  include Fopost::HTTP::Transport

  Call = Struct.new(:method, :uri, :headers, :body, keyword_init: true) do
    def json
      body.nil? ? nil : JSON.parse(body)
    end

    def path
      uri.path
    end
  end

  attr_reader :calls

  def initialize
    @routes = Hash.new { |hash, key| hash[key] = [] }
    @calls = []
  end

  def stub(method, path, status: 200, json: nil, headers: {})
    headers = { 'content-type' => 'application/json' }.merge(headers)
    @routes[key(method, path)] << { status: status, body: JSON.generate(json), headers: headers }
    self
  end

  def call(method:, url:, headers:, body:)
    @calls << Call.new(method: method, uri: url, headers: headers, body: body)

    queued = @routes[key(method, url.path)]
    raise "StubTransport: no stub for #{method} #{url.path}" if queued.empty?

    response = queued.size > 1 ? queued.shift : queued.first
    Fopost::HTTP::Response.new(**response)
  end

  def last
    calls.last
  end

  private

  def key(method, path)
    [method.to_s.upcase, path.sub(API_VERSION_PREFIX, '')]
  end
end

module FopostTestHelpers
  FOPOST_ENV_KEYS = Fopost::Rails::Configuration::ENV_KEYS.values.freeze

  def setup
    super
    @saved_env = FOPOST_ENV_KEYS.to_h { |key| [key, ENV[key]] }
    FOPOST_ENV_KEYS.each { |key| ENV.delete(key) }
    Fopost::Rails.reset!
  end

  def teardown
    @saved_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    Fopost::Rails.reset!
    super
  end

  def transport
    @transport ||= StubTransport.new
  end

  # A request path with the SDK's version prefix removed.
  def resource_path(path)
    path.sub(API_VERSION_PREFIX, '')
  end

  # A client wired to the stub transport, with the SDK's own 429 retry off so a
  # rate limit reaches the job instead of being swallowed.
  def stub_client(max_retries: 1)
    Fopost::Rails.client = Fopost::Client.new(
      api_key: 'fp_test_key',
      transport: transport,
      max_retries: max_retries,
      sleeper: ->(_seconds) {}
    )
  end
end

POST_FIXTURE = {
  'id' => 'post_1',
  'workspace_id' => 'ws_1',
  'status' => 'draft',
  'content' => [{ 'text' => 'Hello from Rails', 'media' => [] }],
  'accounts' => []
}.freeze
