# frozen_string_literal: true

require "test_helper"
require "open3"
require "tempfile"

module OpenUI
  module Rails
    class JavascriptTest < ActiveSupport::TestCase
      JAVASCRIPT_ROOT = Engine.root.join("app/javascript")

      # The controllers a host app registers. Kept explicit so a controller
      # cannot be silently dropped from the engine.
      EXPECTED_CONTROLLERS = %w[
        app/javascript/openui/rails/openui_controller.js
        app/javascript/openui/rails/openui_envelope_controller.js
      ].freeze

      test "the expected Stimulus controllers ship with the engine" do
        EXPECTED_CONTROLLERS.each do |relative_path|
          assert Engine.root.join(relative_path).file?, "expected #{relative_path} to exist"
        end
      end

      test "every shipped JavaScript file is valid ES module syntax" do
        skip "node is not available" unless node_available?

        files = Dir[JAVASCRIPT_ROOT.join("**/*.js")]

        assert_operator files.length, :>=, EXPECTED_CONTROLLERS.length

        files.each do |path|
          Tempfile.create([ File.basename(path, ".js"), ".mjs" ]) do |file|
            file.write(File.read(path))
            file.flush

            _out, err, status = Open3.capture3("node", "--check", file.path)

            assert status.success?, "node --check failed for #{path}:\n#{err}"
          end
        end
      end

      private

      def node_available?
        _out, _err, status = Open3.capture3("node", "--version")
        status.success?
      rescue Errno::ENOENT
        false
      end
    end
  end
end
