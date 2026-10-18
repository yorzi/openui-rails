# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module OpenUI
  module Rails
    class RuntimePackageTest < ActiveSupport::TestCase
      test "tampered downloads are rejected without writing destination assets" do
        Dir.mktmpdir do |directory|
          archive = File.join(directory, "tampered.tgz")
          File.binwrite(archive, "not the pinned archive")
          destination = File.join(directory, "public")

          assert_raises(ConfigurationError) { RuntimePackage.new.install(archive, destination: destination) }
          refute File.exist?(destination)
        end
      end

      test "floating and unverified versions cannot be fetched" do
        assert_raises(ConfigurationError) { RuntimePackage.fetch(destination: "unused", version: "latest") }
      end
    end
  end
end
