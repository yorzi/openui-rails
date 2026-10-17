# frozen_string_literal: true

require "test_helper"
require "open3"
require "tempfile"

module OpenUI
  module Rails
    class JavascriptTest < ActiveSupport::TestCase
      CONTROLLER = Engine.root.join("app/javascript/openui/rails/openui_controller.js")

      test "the Stimulus controller ships with the engine" do
        assert CONTROLLER.file?, "expected #{CONTROLLER} to exist"
      end

      test "the Stimulus controller is valid ES module syntax" do
        skip "node is not available" unless node_available?

        Tempfile.create([ "openui_controller", ".mjs" ]) do |file|
          file.write(CONTROLLER.read)
          file.flush

          _out, err, status = Open3.capture3("node", "--check", file.path)

          assert status.success?, "node --check failed:\n#{err}"
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
