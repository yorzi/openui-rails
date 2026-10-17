# frozen_string_literal: true

require "rails/generators"
require "rails/generators/base"

module OpenUI
  # `bin/rails generate openui:install`
  #
  # Sets up a host app: an initializer, the `config/openui` library directory
  # and the engine mount. It does not fetch the pinned JS runtime; that is a
  # deliberate, reproducible step documented in the generated README and run
  # with `bin/rails openui:runtime:fetch`.
  class InstallGenerator < ::Rails::Generators::Base
    # Thor derives the generator namespace from the class name with its own
    # snake_case, which does not know the OpenUI acronym; set it explicitly so
    # `rails generate openui:install` resolves.
    namespace "openui:install"

    source_root File.expand_path("templates", __dir__)

    desc "Install openui-rails: configuration, library directory and engine mount."

    def create_initializer
      template "config/initializers/openui.rb.tt", "config/initializers/openui.rb"
    end

    def create_library_directory
      template "config/openui/README.md", "config/openui/README.md"
    end

    def mount_engine
      return unless routes_file?

      route 'mount OpenUI::Rails::Engine => "/openui-rails"' unless already_mounted?
    end

    def show_next_steps
      say ""
      say "openui-rails installed.", :green
      say ""
      say "Next steps:"
      say "  1. Generate the library prompt and spec with the pinned CLI:"
      say "     npx --yes @openuidev/cli@0.6.0 generate <entry> --out config/openui/library.prompt.txt --no-telemetry"
      say "  2. Self-host the pinned runtime:"
      say "     bin/rails openui:runtime:fetch"
      say "  3. Register actions and an authorizer (see config/initializers/openui.rb)."
      say ""
    end

    private

    def routes_file?
      File.exist?(File.join(destination_root, "config/routes.rb"))
    end

    def already_mounted?
      File.read(File.join(destination_root, "config/routes.rb")).include?("OpenUI::Rails::Engine")
    end
  end
end
