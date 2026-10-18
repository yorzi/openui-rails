# frozen_string_literal: true

# Dummy-app configuration for the browser (system) tests. It registers two
# small allowlisted actions and an authorizer so the action round-trip can be
# exercised end to end without any host application.
OpenUI::Rails.configure do |config|
  config.library_spec_path = OpenUI::Rails::Engine.root.join("test/fixtures/files/library.spec.json")
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
