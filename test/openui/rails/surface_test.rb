# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    class SurfaceTest < ActiveSupport::TestCase
      test "accepts JSON-style keys and takes an immutable copy" do
        response = +"hello"
        surface = Surface.coerce({ "id" => "json", "response" => response, "context" => { "items" => [ 1 ] } })
        response.replace("changed")

        assert_equal "json", surface.id
        assert_equal "hello", surface.response
        assert_raises(FrozenError) { surface.context["items"] << 2 }
      end

      Record = Struct.new(:id, :version, :library_version, :response, :context)

      test "builds a mount data hash" do
        surface = Surface.new(id: "s1", version: 3, library_version: "sha256:x", response: "root = Card()")

        data = surface.to_mount_data(stream: false, actions_endpoint: "/openui-rails/actions")

        assert_equal "openui", data[:controller]
        assert_equal "s1", data[:openui_surface_id]
        # Values are Strings so Rails never JSON-coerces them (see
        # Surface#to_mount_data). The browser parses the version with Number().
        assert_equal "3", data[:openui_version]
        assert_equal "sha256:x", data[:openui_library_version]
        assert_equal "false", data[:openui_streaming]
        assert_equal "root = Card()", data[:openui_response]
      end

      test "omits nil values and defaults the message id to the surface id" do
        data = Surface.new(id: "s1").to_mount_data(stream: false, actions_endpoint: "/a")

        assert_equal "s1", data[:openui_message_id]
        refute data.key?(:openui_library_version)
        refute data.key?(:openui_response)
      end

      test "stream flag is sticky once set" do
        data = Surface.new(id: "s1", streaming: true).to_mount_data(stream: false, actions_endpoint: "/a")

        assert_equal "true", data[:openui_streaming]
      end

      test "coerces a host record" do
        surface = Surface.coerce(Record.new("s9", 4, "sha256:y", "src", nil))

        assert_equal "s9", surface.id
        assert_equal 4, surface.version
        assert_equal "sha256:y", surface.library_version
        assert_equal "src", surface.response
      end

      test "coercion lets explicit overrides win" do
        surface = Surface.coerce(Record.new("s9", 4), response: "override", version: 9)

        assert_equal "override", surface.response
        assert_equal 9, surface.version
      end

      test "encodes a hash context as JSON in the mount data" do
        data = Surface.new(id: "s1", context: { "formState" => { "note" => "rush" } })
                     .to_mount_data(stream: false, actions_endpoint: "/a")

        assert_equal({ "formState" => { "note" => "rush" } }, JSON.parse(data[:openui_initial_state]))
      end

      test "restores a persisted stream watermark and terminal state" do
        surface = Surface.coerce({ id: "saved", next_sequence: 7, completed: true, response: "saved UI" })
        data = surface.to_mount_data(actions_endpoint: "/a")

        assert_equal 7, surface.next_sequence
        assert_equal true, surface.completed
        assert_equal "7", data[:openui_next_sequence]
        assert_equal "true", data[:openui_completed]
        assert_equal surface.to_h, Surface.coerce(surface).to_h
      end

      test "rejects invalid restored stream state" do
        [ -1, 1.5, "7", 9_007_199_254_740_992 ].each do |value|
          assert_raises(ArgumentError) { Surface.new(id: "saved", next_sequence: value) }
        end
        assert_raises(ArgumentError) { Surface.new(id: "saved", completed: "true") }
        assert_raises(ArgumentError) { Surface.new(id: "saved", streaming: true, completed: true) }
        assert_raises(ArgumentError) { Surface.new(id: "saved", completed: true).to_mount_data(stream: true, actions_endpoint: "/a") }
      end

      test "requires an id" do
        assert_raises(ArgumentError) { Surface.new(id: nil) }
        assert_raises(ArgumentError) { Surface.coerce(Object.new) }
      end
    end
  end
end
