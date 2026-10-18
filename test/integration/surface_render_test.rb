# frozen_string_literal: true

require "test_helper"

class SurfaceRenderTest < ActionDispatch::IntegrationTest
  test "the demo page mounts an OpenUI surface" do
    get "/demo"

    assert_response :success
    assert_select "div[data-controller='openui'].openui-surface" do
      assert_select "[data-openui-surface-id='surface-1']"
      assert_select "[data-openui-version='2']"
      fingerprint = OpenUI::Rails.configuration.library_fingerprint || "sha256:abc123"
      assert_select "[data-openui-library-version='#{fingerprint}']"
      assert_select "[data-openui-streaming='false']"
      assert_select "[data-openui-actions-url='/openui-rails/actions']"
    end
  end

  test "the mount carries the stored response" do
    get "/demo"

    assert_select "[data-openui-response='root = TextContent(\"Hello from OpenUI\")']"
  end
end
