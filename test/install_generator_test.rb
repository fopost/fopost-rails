# frozen_string_literal: true

require 'test_helper'
require 'generators/fopost/install/install_generator'

class InstallGeneratorTest < ::Rails::Generators::TestCase
  tests Fopost::Generators::InstallGenerator
  destination File.expand_path('../tmp/generator', __dir__)
  setup :prepare_destination

  def test_it_writes_the_initializer
    run_generator

    assert_file 'config/initializers/fopost.rb' do |content|
      assert_match(/Fopost::Rails\.configure do \|config\|/, content)
      assert_match(/config\.api_key/, content)
      assert_match(/config\.webhook_secret/, content)
      assert_match(%r{mount Fopost::Rails::Engine => '/fopost'}, content)
    end
  end

  def test_the_initializer_it_writes_is_valid_ruby
    run_generator
    path = File.join(destination_root, 'config/initializers/fopost.rb')

    assert RubyVM::InstructionSequence.compile_file(path)
  end

  def test_it_answers_to_the_fopost_install_namespace
    assert_equal 'fopost:install', Fopost::Generators::InstallGenerator.namespace
  end
end
