# frozen_string_literal: true

require "test_helper"
require "open3"
require "tempfile"

module OpenUI
  module Rails
    class RuntimeAssetTest < ActiveSupport::TestCase
      setup { OpenUI::Rails.reset_configuration! }
      teardown { OpenUI::Rails.reset_configuration! }

      test "defaults to the pinned, self-hosted runtime" do
        config = OpenUI::Rails.configuration

        assert_equal RuntimeAsset::PINNED_VERSION, RuntimeAsset.version(config)
        assert_equal "/openui/openui-browser-bundle-#{RuntimeAsset::PINNED_VERSION}.js", RuntimeAsset.url(config)
        refute RuntimeAsset.external?(config)
      end

      test "honours an explicit version and path" do
        OpenUI::Rails.configure do |config|
          config.runtime_version = "9.9.9"
          config.local_runtime_path = "/assets/openui"
        end

        assert_equal "/assets/openui/openui-browser-bundle-9.9.9.js",
                     RuntimeAsset.url(OpenUI::Rails.configuration)
      end

      test "mount data advertises url, version and integrity" do
        OpenUI::Rails.configure { |config| config.runtime_integrity = "sha384-abc" }

        data = RuntimeAsset.mount_data(OpenUI::Rails.configuration)

        assert_equal "sha384-abc", data[:openui_runtime_integrity]
        assert_equal RuntimeAsset::PINNED_VERSION, data[:openui_runtime_version]
        assert data.key?(:openui_runtime_url)
      end

      test "external assets require an explicit pinned url" do
        OpenUI::Rails.configure do |config|
          config.runtime_assets = :external
          config.library_spec_path = "/tmp/library.spec.json"
        end

        assert_raises(ConfigurationError) { OpenUI::Rails.configuration.validate! }

        OpenUI::Rails.configure do |config|
          config.runtime_url = "https://cdn.example.com/@openuidev/browser-bundle@0.2.1/index.js"
        end

        assert OpenUI::Rails.configuration.validate!
      end
    end
  end
end
