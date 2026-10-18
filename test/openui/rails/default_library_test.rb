# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module OpenUI
  module Rails
    class DefaultLibraryTest < ActiveSupport::TestCase
      setup do
        @root = Dir.mktmpdir("openui-library-test-")
        @configuration = Configuration.new
        @configuration.library_spec_path = File.join(@root, "config/openui/library.spec.json")
        @configuration.prompt_path = File.join(@root, "config/openui/library.prompt.txt")
      end

      teardown { FileUtils.remove_entry(@root) }

      test "prepares the pinned default library and passes configuration validation" do
        paths = DefaultLibrary.prepare(root: @root, configuration: @configuration)

        expected = [ @configuration.library_spec_path, @configuration.prompt_path, File.join(File.dirname(@configuration.prompt_path), "openui.LICENSE.txt") ]
        assert_equal expected.map { |path| File.realpath(path) }.sort, paths.sort
        assert @configuration.validate!
        assert_includes File.read(@configuration.prompt_path), "TextContent"
        assert_operator File.size(@configuration.library_spec_path), :>, 1_000
        assert_equal LibraryManifest.parse(DefaultLibrary.files.fetch("library.spec.json")).fingerprint,
          @configuration.library_fingerprint
      end

      test "repeated preparation preserves identical files" do
        prepare
        time = Time.at(1_700_000_000)
        File.utime(time, time, @configuration.prompt_path)
        prepare

        assert_equal time, File.mtime(@configuration.prompt_path)
      end

      test "refuses to mix or overwrite an existing custom library without force" do
        FileUtils.mkdir_p(File.dirname(@configuration.prompt_path))
        File.write(@configuration.prompt_path, "custom library")

        assert_raises(ConfigurationError) { prepare }
        assert_equal "custom library", File.read(@configuration.prompt_path)
        refute File.exist?(@configuration.library_spec_path)

        DefaultLibrary.prepare(root: @root, configuration: @configuration, force: true)
        assert_equal DefaultLibrary.files.fetch("library.prompt.txt"), File.binread(@configuration.prompt_path)
      end

      test "rejects outside paths and symlink destinations even with force" do
        Dir.mktmpdir do |outside|
          @configuration.prompt_path = File.join(outside, "prompt.txt")
          assert_raises(ConfigurationError) { prepare }
          refute File.exist?(@configuration.library_spec_path)

          File.symlink(outside, File.join(@root, "linked"))
          @configuration.prompt_path = File.join(@root, "linked/prompt.txt")
          assert_raises(ConfigurationError) { prepare }

          File.write(File.join(outside, "prompt.txt"), "keep me")
          File.symlink(File.join(outside, "prompt.txt"), File.join(@root, "prompt.txt"))
          @configuration.prompt_path = File.join(@root, "prompt.txt")
          assert_raises(ConfigurationError) { DefaultLibrary.prepare(root: @root, configuration: @configuration, force: true) }
          assert_equal "keep me", File.read(File.join(outside, "prompt.txt"))
        end
      end

      test "requires distinct regular-file targets and both configured paths" do
        @configuration.prompt_path = @configuration.library_spec_path
        assert_raises(ConfigurationError) { prepare }
        @configuration.prompt_path = nil
        assert_raises(ConfigurationError) { prepare }
        @configuration.prompt_path = @root
        assert_raises(ConfigurationError) { prepare }
      end

      test "rejects corrupt or incomplete bundled exports" do
        directory = File.join(@root, "exports")
        FileUtils.cp_r(DefaultLibrary::DIRECTORY, directory)
        File.write(File.join(directory, "library.prompt.txt"), "tampered")
        assert_raises(ConfigurationError) { DefaultLibrary.files(directory: directory) }
        File.write(File.join(directory, "provenance.json"), "invalid JSON")
        assert_raises(ConfigurationError) { DefaultLibrary.files(directory: directory) }
      end

      private

      def prepare
        DefaultLibrary.prepare(root: @root, configuration: @configuration)
      end
    end
  end
end
