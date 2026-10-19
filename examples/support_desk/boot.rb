# frozen_string_literal: true

# Explicitly loaded by the reference host. Never loaded by require "openui/rails".
module SupportDesk # :nodoc:
  class Engine < ::Rails::Engine
    isolate_namespace SupportDesk
    engine_name "support_desk"
    config.root = File.expand_path(__dir__)

    initializer "support_desk.assets", before: "importmap" do |app|
      app.config.assets.paths << root.join("app/javascript")
      app.config.importmap.paths << root.join("config/importmap.rb")
    end
  end
end
