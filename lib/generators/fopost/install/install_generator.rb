# frozen_string_literal: true

require 'rails/generators/base'

module Fopost
  module Generators
    # `rails generate fopost:install`
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Writes config/initializers/fopost.rb.'

      def copy_initializer
        template 'fopost.rb.tt', 'config/initializers/fopost.rb'
      end

      def print_next_steps
        say <<~TEXT

          Next: put your API key somewhere the app can read it.

            bin/rails credentials:edit     # fopost: { api_key: fp_... }
            # or export FOPOST_API_KEY=fp_...

          Create a key at https://fopost.com/dashboard/api-keys.
        TEXT
      end
    end
  end
end
