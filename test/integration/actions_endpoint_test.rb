# frozen_string_literal: true

require "test_helper"

class ActionsEndpointTest < ActionDispatch::IntegrationTest
  setup do
    OpenUI::Rails.reset_configuration!
    @config = OpenUI::Rails.configuration
  end

  teardown do
    OpenUI::Rails.reset_configuration!
    ActionController::Base.allow_forgery_protection = false
  end

  def register(name, authorize: ->(_invocation) { true }, **options, &handler)
    handler ||= ->(invocation) { { "echo" => invocation.args["orderId"] } }
    @config.action_registry.register(name, handler: handler, authorize: authorize, **options)
  end

  def payload(overrides = {})
    {
      action: "orders.refresh",
      args: { orderId: 42 },
      surface_id: "surface-1",
      version: 1,
      idempotency_key: "idem-#{SecureRandom.hex(4)}"
    }.merge(overrides)
  end

  test "a permitted action returns its result" do
    register("orders.refresh")

    post "/openui-rails/actions", params: payload, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "orders.refresh", body.dig("result", "action")
    assert_equal 42, body.dig("result", "value", "echo")
    assert_equal false, body.dig("result", "replayed")
  end

  test "an unknown action fails with a structured 404" do
    post "/openui-rails/actions", params: payload(action: "nope"), as: :json

    assert_response :not_found
    assert_equal "unknown_action", JSON.parse(response.body).dig("error", "code")
  end

  test "an unauthorized action fails with a structured 403" do
    register("orders.refresh", authorize: ->(_invocation) { false })

    post "/openui-rails/actions", params: payload, as: :json

    assert_response :forbidden
    assert_equal "unauthorized", JSON.parse(response.body).dig("error", "code")
  end

  test "an invalid payload fails with a structured 422" do
    register("orders.refresh", schema: { orderId: Integer })

    post "/openui-rails/actions", params: payload(args: { orderId: "x" }), as: :json

    assert_response :unprocessable_content
    assert_equal "invalid_action", JSON.parse(response.body).dig("error", "code")
  end

  test "a duplicate submission is replayed, not re-executed" do
    calls = 0
    register("orders.refresh") { |_invocation| calls += 1; "once" }
    body = payload(idempotency_key: "fixed-key")

    post "/openui-rails/actions", params: body, as: :json
    assert_response :success

    post "/openui-rails/actions", params: body, as: :json
    assert_response :success
    assert_equal true, JSON.parse(response.body).dig("result", "replayed")
    assert_equal 1, calls
  end

  test "a server-side gem error is a generic 500 without internal details" do
    register("orders.refresh")
    @config.actor_resolver = ->(_controller) { Object.new }

    post "/openui-rails/actions", params: payload, as: :json

    assert_response :internal_server_error
    assert_equal({ "code" => "error", "message" => "action failed" }, JSON.parse(response.body)["error"])
  end

  test "a missing CSRF token is rejected when forgery protection is on" do
    register("orders.refresh")
    ActionController::Base.allow_forgery_protection = true

    post "/openui-rails/actions", params: payload, as: :json

    assert_response :unprocessable_content
    assert_equal "csrf_failed", JSON.parse(response.body).dig("error", "code")
  end

  test "malformed action names are request errors rather than configuration errors" do
    post "/openui-rails/actions", params: payload(action: "<invalid>"), as: :json

    assert_response :unprocessable_content
    assert_equal "invalid_action", JSON.parse(response.body).dig("error", "code")
  end

  test "the engine inherits host authentication and rejects a swapped surface" do
    assert_operator OpenUI::Rails::ActionsController, :<, ::ApplicationController
    calls = []
    register("orders.refresh") { calls << :called }
    @config.actor_resolver = ->(*) { :alice }
    @config.surface_resolver = ->(id, actor:, **) do
      OpenUI::Rails::Surface.new(id: id, version: 1) if actor == :alice && id == "owned"
    end

    post "/openui-rails/actions", params: payload(surface_id: "another-tenant"), as: :json
    assert_response :forbidden
    assert_empty calls

    post "/openui-rails/actions", params: payload(surface_id: "owned"), as: :json
    assert_response :success
    assert_equal [ :called ], calls
  end
end
