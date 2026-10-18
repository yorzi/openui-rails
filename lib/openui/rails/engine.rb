# frozen_string_literal: true

require "rails"
require "active_support/inflector"
require "rails/engine"

# Register the acronym before the engine class is defined: `isolate_namespace`
# computes the routing module scope with `underscore` at class-definition time,
# so it must already know that `OpenUI` is `openui` (not `open_ui`).
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "OpenUI"
end

module OpenUI
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace OpenUI::Rails

      # Inside `module OpenUI`, a bare `Rails` resolves to `OpenUI::Rails`, so
      # every reference to the framework must be written `::Rails`.
      #
      # Zeitwerk would infer `Openui` from the `openui` path segment; the
      # acronym must be declared explicitly before the main autoloader is set
      # up, otherwise constants such as `OpenUI::Rails::ActionsController`
      # cannot be resolved.
      initializer "openui_rails.inflections", before: :setup_main_autoloader do
        ::Rails.autoloaders.main.inflector.inflect("openui" => "OpenUI")
      end

      # Expose the surface helper to every host view.
      initializer "openui_rails.view_helper" do
        ActiveSupport.on_load(:action_view) do
          include OpenUI::Rails::ViewHelper
        end
      end

      # Make the Stimulus controller reachable by Propshaft/Sprockets/importmap.
      initializer "openui_rails.assets" do |app|
        next unless app.config.respond_to?(:assets)

        assets = app.config.assets
        assets.paths << root.join("app/javascript") if assets.respond_to?(:paths)
      end
    end
  end
end
