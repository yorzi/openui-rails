# frozen_string_literal: true

OpenUI::Rails.configure do |config|
  library = ENV.fetch("OPENUI_REFERENCE_LIBRARY_DIR") { Rails.root.join("config/openui") }
  config.library_spec_path = File.join(library, "library.spec.json")
  config.prompt_path = File.join(library, "library.prompt.txt")
  config.actor_resolver = ->(controller) { SupportDesk::User.find_by(id: controller.session[:support_desk_user_id]) }
  config.surface_resolver = ->(id, actor:, **) {
    SupportDesk::Conversation.find_by(id: id, user_id: actor.id, tenant_id: actor.tenant_id) if actor
  }
  config.idempotency_store = OpenUI::Rails::Actions::Idempotency::ActiveRecordStore.new
  config.idempotency_scope = ->(invocation) { [ invocation.actor.tenant_id, invocation.actor.id ] }
  config.authorize_action = ->(invocation) {
    actor, conversation = invocation.actor, invocation.surface
    actor && conversation && conversation.user_id == actor.id && conversation.tenant_id == actor.tenant_id &&
      (invocation.action == "ticket_lookup" || actor.role == "agent")
  }
end
OpenUI::Rails.actions.register "ticket_lookup", schema: {}, handler: ->(invocation) {
  ticket = invocation.surface.ticket
  { "title" => ticket.title, "status" => ticket.status }
}
OpenUI::Rails.actions.register "close_ticket", schema: {}, handler: ->(invocation) {
  invocation.surface.close_ticket!(invocation)
}
OpenUI::Rails.actions.register "continue_conversation",
  schema: ->(args) {
    (args.keys - %w[message context form_name form_state]).empty? &&
      args["message"].is_a?(String) && args["message"].bytesize.between?(1, 1000) &&
      (!args.key?("context") || args["context"].is_a?(String) && args["context"].bytesize <= 1000) &&
      (!args.key?("form_name") || args["form_name"] == "reply") &&
      (!args.key?("form_state") || SupportDesk::Conversation.valid_form_state?(args["form_state"]))
  }, handler: ->(invocation) { invocation.surface.continue!(invocation) }
