# frozen_string_literal: true

# Explicitly loaded by the reference host. Never loaded by require "openui/rails".
module SupportDesk # :nodoc:
  class Engine < ::Rails::Engine
    isolate_namespace SupportDesk
    engine_name "support_desk"
    config.root = File.expand_path(__dir__)

    # The documented local review uses RAILS_ENV=test. Keep the reference's
    # form tags and the shared action endpoint protected in that environment too.
    initializer "support_desk.csrf", before: "action_controller.set_configs" do |app|
      app.config.action_controller.allow_forgery_protection = true
    end

    initializer "support_desk.assets", before: "importmap" do |app|
      app.config.assets.paths << root.join("app/javascript")
      app.config.importmap.paths << root.join("config/importmap.rb")
    end
  end
end
