# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    class ConfigurationTest < ActiveSupport::TestCase
      setup do
        OpenUI::Rails.reset_configuration!
      end

      teardown do
        OpenUI::Rails.reset_configuration!
      end

      test "has safe defaults" do
        config = OpenUI::Rails.configuration

        assert_equal :turbo, config.transport
        assert_equal :self_hosted, config.runtime_assets
        assert_equal Configuration::DEFAULT_ACTIONS_ENDPOINT, config.actions_endpoint
        assert_equal Configuration::DEFAULT_STREAM_BYTE_LIMIT, config.stream_byte_limit
        assert_equal Configuration::DEFAULT_PENDING_BYTE_LIMIT, config.pending_byte_limit
        assert_nil config.library_spec_path
        assert_nil config.prompt_path
      end

      test "legacy library_name and surface_id_param are deprecated no-ops" do
        config = OpenUI::Rails.configuration

        assert_deprecated(/library_name has no effect/, OpenUI::Rails.deprecator) { config.library_name = :custom }
        assert_deprecated(/library_name has no effect/, OpenUI::Rails.deprecator) { assert_equal :custom, config.library_name }
        assert_deprecated(/surface_id_param has no effect/, OpenUI::Rails.deprecator) { config.surface_id_param = :id }
        assert_deprecated(/surface_id_param has no effect/, OpenUI::Rails.deprecator) { assert_equal :id, config.surface_id_param }
        assert_same OpenUI::Rails.deprecator, ::Rails.application.deprecators[:openui_rails]
      end

      test "configure yields a memoized singleton" do
        yielded = nil
        result = OpenUI::Rails.configure { |c| yielded = c }

        assert_same result, yielded
        assert_same OpenUI::Rails.configuration, yielded
      end

      test "rejects an unsupported transport" do
        assert_raises(ConfigurationError) do
          OpenUI::Rails.configure { |c| c.transport = :carrier_pigeon }
        end
      end

      test "rejects an unsupported asset strategy" do
        assert_raises(ConfigurationError) do
          OpenUI::Rails.configure { |c| c.runtime_assets = :cdn }
        end
      end

      test "accepts a usable custom idempotency store" do
        store = Object.new
        def store.claim(*) = true
        def store.record(*, **) = true

        OpenUI::Rails.configure { |c| c.idempotency_store = store }

        assert_same store, OpenUI::Rails.configuration.idempotency_store
      end

      test "rejects an idempotency store without #claim" do
        assert_raises(ConfigurationError) do
          OpenUI::Rails.configure { |c| c.idempotency_store = Object.new }
        end
      end

      test "validates the authorizer and surface resolver are callable" do
        assert_raises(ConfigurationError) { OpenUI::Rails.configure { |c| c.authorize_action = :nope } }
        assert_raises(ConfigurationError) { OpenUI::Rails.configure { |c| c.surface_resolver = "nope" } }

        OpenUI::Rails.configure do |c|
          c.authorize_action = ->(_invocation) { true }
          c.surface_resolver = ->(_id, **) { nil }
        end

        assert_respond_to OpenUI::Rails.configuration.authorize_action, :call
      end

      test "validate! fails fast when the library spec is missing" do
        error = assert_raises(ConfigurationError) { OpenUI::Rails.configuration.validate! }
        assert_match(/library_spec_path/, error.message)
      end

      test "validate! rejects nonsensical byte limits" do
        OpenUI::Rails.configure do |c|
          c.library_spec_path = "/tmp/library.spec.json"
          c.stream_byte_limit = 10
          c.pending_byte_limit = 20
        end

        assert_raises(ConfigurationError) { OpenUI::Rails.configuration.validate! }
      end

      test "readiness validates actual manifest and prompt files" do
        config = OpenUI::Rails.configuration
        config.library_spec_path = file_fixture("library.spec.json")
        config.prompt_path = file_fixture("library.prompt.txt")
        assert config.validate!

        config.prompt_path = file_fixture("library.prompt.txt").dirname.join("missing-prompt.txt")
        assert_raises(ManifestError) { config.validate! }
        config.prompt_path = nil
        config.library_spec_path = file_fixture("library.spec.json").dirname.join("missing-library.json")
        assert_raises(ManifestError) { config.validate! }
      end

      test "provides a process-wide default idempotency store" do
        store = OpenUI::Rails.configuration.idempotency_store

        assert_instance_of Actions::Idempotency::MemoryStore, store
        assert_same store, OpenUI::Rails.configuration.idempotency_store
      end

      test "reset! preserves the action registry and idempotency store" do
        OpenUI::Rails.actions.register("keep.me") { |_invocation| nil }
        store = OpenUI::Rails.configuration.idempotency_store

        OpenUI::Rails.configuration.reset!

        assert OpenUI::Rails.actions.registered?("keep.me")
        assert_same store, OpenUI::Rails.configuration.idempotency_store
      end

      test "reset_configuration! drops all state" do
        OpenUI::Rails.configure { |c| c.transport = :action_cable }
        OpenUI::Rails.reset_configuration!

        assert_equal :turbo, OpenUI::Rails.configuration.transport
      end
    end
  end
end
