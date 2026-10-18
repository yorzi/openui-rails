# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module OpenUI
  module Rails
    class DoctorTest < ActiveSupport::TestCase
      setup do
        @root = Dir.mktmpdir("openui-doctor-test-")
        @configuration = Configuration.new
        @configuration.library_spec_path = File.join(@root, "library.spec.json")
        @configuration.prompt_path = File.join(@root, "library.prompt.txt")
        DefaultLibrary.prepare(root: @root, configuration: @configuration)
      end

      teardown { FileUtils.remove_entry(@root) }

      test "reports missing assets with remediation without changing files" do
        before = Dir["#{@root}/**/*"].select { |path| File.file?(path) }.to_h { |path| [ path, File.binread(path) ] }
        result = diagnose

        refute result.ok?
        assert result.checks.any? { |entry| entry.name == "runtime js" && entry.status == :fail }
        assert_includes result.to_s, "openui:runtime:fetch"
        assert_equal before, before.keys.to_h { |path| [ path, File.binread(path) ] }
        refute File.exist?(File.join(@root, "public"))
      end

      test "redacts invalid manifest and prompt contents" do
        secret = "private-example-not-for-logs"
        File.write(@configuration.library_spec_path, "{#{secret}")
        File.write(@configuration.prompt_path, secret)

        result = diagnose
        refute result.ok?
        refute_includes result.to_s, secret
        assert_includes result.to_s, "library"
      end

      test "rejects a changed default prompt and incompatible default spec" do
        File.write(@configuration.prompt_path, "changed prompt")
        assert diagnose.checks.any? { |entry| entry.name == "library identity" && entry.status == :fail }
        File.write(@configuration.library_spec_path, '{"components":[]}')
        assert diagnose.checks.any? { |entry| entry.name == "library identity" && entry.status == :fail }
      end

      test "does not invoke host callbacks or claim browser and external checks passed" do
        @configuration.runtime_assets = :external
        @configuration.runtime_url = "https://example.test/runtime-1.0.js"
        @configuration.runtime_stylesheet_url = "https://example.test/runtime-1.0.css"
        @configuration.runtime_integrity = RuntimePackage::FILES.fetch("package/dist/openui-bundle.min.js").last
        @configuration.runtime_stylesheet_integrity = RuntimePackage::FILES.fetch("package/dist/openui-styles.css").last
        @configuration.authorize_action = ->(*) { flunk "doctor must not execute authorization" }
        @configuration.surface_resolver = ->(*) { flunk "doctor must not resolve a surface" }

        result = diagnose
        assert result.ok?, result.to_s
        %w[browser authorization].each do |name|
          assert result.checks.any? { |entry| entry.name == name && entry.status == :unverified }
        end
        assert result.checks.any? { |entry| entry.name == "runtime assets" && entry.status == :unverified }
      end

      test "inspects mount definitions without running request constraints" do
        # This object exposes definitions only, with no request recognizer.
        routes = Struct.new(:routes).new(::Rails.application.routes.routes)
        result = Doctor.new(root: @root, configuration: @configuration, routes: routes).run
        assert result.checks.any? { |entry| entry.name == "actions route" && entry.status == :pass }
      end

      test "does not claim a custom stylesheet was verified against local default CSS" do
        @configuration.runtime_stylesheet_url = "https://example.test/custom.css"
        assert diagnose.checks.any? { |entry| entry.name == "runtime assets" && entry.status == :unverified }
      end

      test "detects incorrect mount configuration and a missing custom stylesheet" do
        @configuration.actions_endpoint = "/not-mounted/actions"
        assert diagnose.checks.any? { |entry| entry.name == "actions route" && entry.status == :fail }
        @configuration.runtime_assets = :external
        @configuration.runtime_url = "https://example.test/custom.js"
        assert diagnose.checks.any? { |entry| entry.name == "runtime assets" && entry.status == :fail }
      end

      test "detects checksum mismatch and does not read outside public assets" do
        FileUtils.mkdir_p(File.join(@root, "public/openui"))
        File.write(File.join(@root, "public/openui/openui-browser-bundle-0.2.1.js"), "not the real bundle")
        assert diagnose.checks.any? { |entry| entry.name == "runtime js" && entry.status == :fail }
        @configuration.local_runtime_path = "/../../elsewhere"
        assert diagnose.checks.any? { |entry| entry.name == "runtime assets" && entry.status == :fail }
      end

      private

      def diagnose
        Doctor.new(root: @root, configuration: @configuration, routes: ::Rails.application.routes).run
      end
    end
  end
end
