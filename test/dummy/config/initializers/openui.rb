# frozen_string_literal: true

# Dummy-app configuration for the browser (system) tests. It registers two
# small allowlisted actions and an authorizer so the action round-trip can be
# exercised end to end without any host application.
unless ENV["OPENUI_REFERENCE"]
OpenUI::Rails.configure do |config|
  # The deterministic renderer double is deliberately not the upstream asset.
  if ENV["OPENUI_REAL_RUNTIME_DIR"]
    config.runtime_url = "/audit-runtime/runtime.js"
    config.runtime_stylesheet_url = "/audit-runtime/runtime.css"
    config.runtime_integrity = OpenUI::Rails::RuntimePackage::FILES.fetch("package/dist/openui-bundle.min.js").last
    config.runtime_stylesheet_integrity = OpenUI::Rails::RuntimePackage::FILES.fetch("package/dist/openui-styles.css").last
  else
    config.runtime_url = "/openui/openui-browser-bundle-0.2.1.js"
  end
  config.library_spec_path = OpenUI::Rails::Engine.root.join("test/fixtures/files/library.spec.json")
  config.library_spec_path = nil if ENV["OPENUI_REAL_RUNTIME_DIR"]
  config.prompt_path = OpenUI::Rails::Engine.root.join("test/fixtures/files/library.prompt.txt")

  config.actor_resolver = ->(_controller) { "e2e-actor" }
  config.authorize_action = ->(invocation) { invocation.actor == "e2e-actor" }

  config.surface_resolver = lambda do |surface_id, actor:, **|
    versions = { "surface-1" => 2, "surface-2" => 0 }
    next nil unless actor == "e2e-actor" && versions.key?(surface_id)

    OpenUI::Rails::Surface.new(id: surface_id, version: versions.fetch(surface_id))
  end
end

OpenUI::Rails.actions.register "do.thing",
  description: "Test action",
  schema: { "x" => Integer },
  handler: ->(invocation) { { "ok" => true, "x" => invocation.args["x"] } }

OpenUI::Rails.actions.register "Lookup",
  description: "Test browser tool",
  schema: { "q" => String },
  handler: ->(invocation) { { "found" => invocation.args["q"] } }

# Requires explicit confirmation: the dispatcher rejects it unless the browser
# submits `confirmed: true` (see the confirmation system test).
OpenUI::Rails.actions.register "do.destructive",
  description: "Test confirmation gate",
  confirmation: true,
  schema: {},
  handler: ->(_invocation) { { "deleted" => true } }

OpenUI::Rails.actions.register "continue_conversation",
  handler: ->(invocation) { invocation.args }

end

if ENV["OPENUI_REFERENCE"] && ENV["OPENUI_REAL_RUNTIME_DIR"]
  OpenUI::Rails.configure do |config|
    config.runtime_url = "/audit-runtime/runtime.js"
    config.runtime_stylesheet_url = "/audit-runtime/runtime.css"
    config.runtime_integrity = OpenUI::Rails::RuntimePackage::FILES.fetch("package/dist/openui-bundle.min.js").last
    config.runtime_stylesheet_integrity = OpenUI::Rails::RuntimePackage::FILES.fetch("package/dist/openui-styles.css").last
  end
end
