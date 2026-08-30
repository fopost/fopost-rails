# frozen_string_literal: true

require_relative 'lib/fopost/rails/version'

Gem::Specification.new do |spec|
  spec.name = 'fopost-rails'
  spec.version = Fopost::Rails::VERSION
  spec.authors = ['FoPost', 'Porter Bridge, LLC']
  spec.license = 'MIT'

  spec.summary = 'Official Rails integration for the FoPost API.'
  spec.description = 'Rails integration for the FoPost API: configuration and credentials, a ' \
                     'memoized client, ActiveJob jobs, and a mountable webhook endpoint. A thin ' \
                     'wrapper around the fopost gem.'
  spec.homepage = 'https://fopost.com'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => 'https://github.com/fopost/fopost-rails',
    'bug_tracker_uri' => 'https://github.com/fopost/fopost-rails/issues',
    'documentation_uri' => 'https://fopost.com/docs',
    'changelog_uri' => 'https://github.com/fopost/fopost-rails/blob/main/CHANGELOG.md',
    'rubygems_mfa_required' => 'true'
  }

  spec.required_ruby_version = '>= 3.1'

  spec.files = Dir['lib/**/*', 'app/**/*', 'config/**/*'] + %w[LICENSE README.md CHANGELOG.md]
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '>= 7.0', '< 9'
  spec.add_dependency 'fopost', '~> 0.1'
  spec.add_dependency 'railties', '>= 7.0', '< 9'
end
