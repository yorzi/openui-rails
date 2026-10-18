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
      say "  1. Prepare the default chat library (no browser, Node, or provider required):"
      say "     bin/rails openui:library:prepare"
      say "  2. Self-host the pinned runtime:"
      say "     bin/rails openui:runtime:fetch"
      say "  3. Pin/register the Stimulus controllers and include openui_stylesheet_tag in your layout."
      say "  4. Run bin/rails openui:doctor, then verify rendering in a browser."
      say "  5. Configure scoped surfaces and authorization before enabling actions."
      say "     Custom libraries require a matching custom runtime; see config/openui/README.md."
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
