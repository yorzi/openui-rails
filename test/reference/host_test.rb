# frozen_string_literal: true

if ENV["OPENUI_REFERENCE"]
  require File.join(ENV.fetch("OPENUI_REFERENCE_HOST"), "config/environment")
  # The runner creates this schema from the packaged example migrations.
  # Loading test/dummy's unrelated schema would erase it.
  ActiveRecord.maintain_test_schema = false
  require "rails/test_help"

  class ReferenceHostTest < ActiveSupport::TestCase
    setup do
      SupportDesk::Demo.seed!
      @alice = SupportDesk::User.find_by!(name: "Alice")
      @conversation = SupportDesk::Conversation.find_by!(user_id: @alice.id)
    end

    test "canonical frames and snapshot have one persisted watermark" do
      frames = @conversation.generate!
      assert frames.first.delta?
      assert frames.last.completed?
      assert_equal frames.length, @conversation.reload.next_sequence
      assert_equal frames.select(&:delta?).map(&:delta).join, @conversation.response
      assert_equal frames.last.sequence, @conversation.snapshot.sequence
      assert @conversation.generate!.first.snapshot?, "repeat stream must not regenerate a completed response"
      assert_equal true, @conversation.surface.completed
    end

    test "wrong actor or tenant cannot resolve a conversation" do
      @conversation.generate!
      bob = SupportDesk::User.find_by!(name: "Bob")
      dispatcher = OpenUI::Rails::Actions::Dispatcher.from_configuration
      assert_raises(OpenUI::Rails::UnauthorizedActionError) { dispatcher.call(payload("close_ticket"), actor: bob) }
      assert_raises(OpenUI::Rails::UnauthorizedActionError) { dispatcher.call(payload("ticket_lookup"), actor: nil) }
      assert_equal "open", @conversation.ticket.reload.status
    end

    test "database transaction rejects a stale invocation even after dispatcher checks" do
      invocation = OpenUI::Rails::Actions::Invocation.new(action: "close_ticket", args: {}, actor: @alice,
        surface: @conversation, tenant: nil, context: {}, submission: OpenUI::Rails::Actions::Submission.parse(payload("close_ticket")))
      @conversation.update!(version: 1)
      assert_raises(OpenUI::Rails::StaleSurfaceError) { @conversation.close_ticket!(invocation) }
      assert_equal "open", @conversation.ticket.reload.status
      assert_equal 0, SupportDesk::Receipt.where(ticket_id: @conversation.ticket_id).count
    end

    test "closing persists one business receipt and fences repeats after store reset" do
      dispatcher = OpenUI::Rails::Actions::Dispatcher.from_configuration
      dispatcher.call(payload("close_ticket"), actor: @alice)
      OpenUI::Rails.configuration.idempotency_store = OpenUI::Rails::Actions::Idempotency::MemoryStore.new
      assert_raises(OpenUI::Rails::StaleSurfaceError) do
        OpenUI::Rails::Actions::Dispatcher.from_configuration.call(payload("close_ticket"), actor: @alice)
      end
      assert_equal "closed", @conversation.ticket.reload.status
      assert_equal 1, SupportDesk::Receipt.where(ticket_id: @conversation.ticket_id).count
      assert_raises(ActiveRecord::RecordNotUnique) do
        SupportDesk::Receipt.create!(ticket_id: @conversation.ticket_id, operation: "close")
      end
    end

    test "conversation continuation stores validated text and starts a new message" do
      @conversation.generate!
      original = @conversation.message_id
      args = { "message" => "Review this ticket", "form_name" => "reply", "form_state" => note_state("Keep this note") }
      OpenUI::Rails::Actions::Dispatcher.from_configuration.call(payload("continue_conversation", args), actor: @alice)
      @conversation.reload
      assert_equal "Review this ticket", @conversation.messages.last.fetch("text")
      assert_equal note_state("Keep this note"), @conversation.form_state
      assert_equal "", @conversation.response
      refute_equal original, @conversation.message_id
      assert_equal 0, @conversation.next_sequence
    end

    test "state writes reject stale versions invalid fields and oversized values" do
      @conversation.save_form!(note_state("Saved"), expected_version: 0)
      assert_raises(OpenUI::Rails::StaleSurfaceError) { @conversation.save_form!(note_state("Lost"), expected_version: 4) }
      [ { "secret" => "no" }, note_state("x" * 2001), { "reply" => { "note" => { "value" => 1 } } } ].each do |state|
        assert_raises(OpenUI::Rails::InvalidActionError) { @conversation.save_form!(state, expected_version: 0) }
      end
      assert_equal note_state("Saved"), @conversation.reload.form_state
    end

    test "query does not grant mutation permission to a reader" do
      reader = SupportDesk::User.find_by!(name: "Reader")
      conversation = SupportDesk::Conversation.find_by!(user_id: reader.id)
      body = payload("ticket_lookup").merge(surface_id: conversation.id.to_s)
      dispatcher = OpenUI::Rails::Actions::Dispatcher.from_configuration
      assert_equal "open", dispatcher.call(body, actor: reader).value["status"]
      assert_raises(OpenUI::Rails::UnauthorizedActionError) { dispatcher.call(body.merge(action: "close_ticket"), actor: reader) }
    end

    private

    def note_state(value) = { "reply" => { "note" => { "value" => value, "componentType" => "Input" } } }

    def payload(action, args = {})
      { action: action, args: args, surface_id: @conversation.id.to_s, version: 0,
        idempotency_key: SecureRandom.uuid }
    end
  end
  class ReferenceHostRequestTest < ActionDispatch::IntegrationTest
    setup do
      SupportDesk::Demo.seed!
      @alice = SupportDesk::User.find_by!(name: "Alice")
      @conversation = SupportDesk::Conversation.find_by!(user_id: @alice.id)
      post "/support/session", params: { name: "Alice" }
      assert_response :redirect
    end

    test "JSON state has one explicit shape on a generated Rails host" do
      path = "/support/conversations/#{@conversation.id}/state"
      state = { "reply" => { "note" => { "value" => "Saved note", "componentType" => "Input" } } }
      patch path, params: { state: state, version: 0 }, as: :json
      assert_response :no_content
      assert_equal state, @conversation.reload.form_state
      patch path, params: { state: {}, version: 9 }, as: :json
      assert_response :conflict
      patch path, params: { state: {}, version: "invalid" }, as: :json
      assert_response :unprocessable_content
      patch path, params: { state: [], version: 0 }, as: :json
      assert_response :unprocessable_content
      assert_equal state, @conversation.reload.form_state
    end

    test "snapshot and stream require a scoped session" do
      @conversation.generate!
      get "/support/conversations/#{@conversation.id}/snapshot"
      assert_response :success
      assert_equal @conversation.message_id, response.parsed_body["message_id"]
      post "/support/session", params: { name: "Bob" }
      get "/support/conversations/#{@conversation.id}/snapshot"
      assert_response :not_found
      post "/support/conversations/#{@conversation.id}/stream"
      assert_response :not_found
      delete "/support/session"
      get "/support/conversations/#{@conversation.id}/snapshot"
      assert_response :unauthorized
    end
  end

end
