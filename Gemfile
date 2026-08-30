# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# The parent SDK is not on RubyGems yet, so resolve it from source. The gemspec
# keeps the normal `fopost ~> 0.1` dependency, which is what ships. Delete this
# line once the gem is published.
gem 'fopost', github: 'fopost/fopost-ruby'

gem 'rails', '>= 7.0'

group :development do
  gem 'minitest', '~> 5.20'
  gem 'rake', '~> 13.0'
  gem 'rubocop', '~> 1.60'
  gem 'rubocop-minitest', '~> 0.34'
end
