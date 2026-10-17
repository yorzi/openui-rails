# frozen_string_literal: true

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
    end
  end
end
