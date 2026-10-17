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
        assert_equal :chat, config.library_name
        assert_equal Configuration::DEFAULT_ACTIONS_ENDPOINT, config.actions_endpoint
        assert_equal Configuration::DEFAULT_STREAM_BYTE_LIMIT, config.stream_byte_limit
        assert_equal Configuration::DEFAULT_PENDING_BYTE_LIMIT, config.pending_byte_limit
        assert_nil config.library_spec_path
        assert_nil config.prompt_path
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

        OpenUI::Rails.configure { |c| c.idempotency_store = store }

        assert_same store, OpenUI::Rails.configuration.idempotency_store
      end

      test "rejects an idempotency store without #claim" do
        assert_raises(ConfigurationError) do
          OpenUI::Rails.configure { |c| c.idempotency_store = Object.new }
        end
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

      test "reset_configuration! drops all state" do
        OpenUI::Rails.configure { |c| c.transport = :action_cable }
        OpenUI::Rails.reset_configuration!

        assert_equal :turbo, OpenUI::Rails.configuration.transport
      end
    end
  end
end
