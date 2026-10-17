# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    class PromptBuilderTest < ActiveSupport::TestCase
      setup do
        @manifest = LibraryManifest.load(file_fixture("library.spec.json"))
        @prompt = file_fixture("library.prompt.txt").read
      end

      test "combines framing instructions with the library prompt" do
        builder = PromptBuilder.new(manifest: @manifest, library_prompt: @prompt)

        assert_includes builder.system_instruction, PromptBuilder::DEFAULT_INSTRUCTIONS.strip
        assert_includes builder.system_instruction, "Available components: Card, Table, Chart."
      end

      test "works without a library prompt" do
        builder = PromptBuilder.new(manifest: @manifest)

        assert_equal PromptBuilder::DEFAULT_INSTRUCTIONS.strip, builder.system_instruction
      end

      test "fingerprint is stable and scheme tagged" do
        builder = PromptBuilder.new(manifest: @manifest, library_prompt: @prompt)

        assert_match(%r{\Asha256:[0-9a-f]{64}\z}, builder.fingerprint)
        assert_equal builder.fingerprint,
                     PromptBuilder.new(manifest: @manifest, library_prompt: @prompt).fingerprint
      end

      test "fingerprint changes when the library revision changes" do
        other = LibraryManifest.build(@manifest.document.merge("version" => "1.3.0"))

        refute_equal PromptBuilder.new(manifest: @manifest, library_prompt: @prompt).fingerprint,
                     PromptBuilder.new(manifest: other, library_prompt: @prompt).fingerprint
      end

      test "fingerprint changes when the prompt changes" do
        refute_equal PromptBuilder.new(manifest: @manifest, library_prompt: @prompt).fingerprint,
                     PromptBuilder.new(manifest: @manifest, library_prompt: "#{@prompt}extra").fingerprint
      end

      test "matches? compares against a persisted fingerprint" do
        builder = PromptBuilder.new(manifest: @manifest, library_prompt: @prompt)

        assert builder.matches?(builder.fingerprint)
        refute builder.matches?("sha256:0")
        refute builder.matches?(nil)
      end

      test "load reads the prompt and manifest from configuration" do
        OpenUI::Rails.configure do |config|
          config.library_spec_path = file_fixture("library.spec.json")
          config.prompt_path = file_fixture("library.prompt.txt")
        end

        builder = PromptBuilder.load

        assert_includes builder.system_instruction, "Support library"
        assert_equal "support", builder.manifest.name
      ensure
        OpenUI::Rails.reset_configuration!
      end

      test "load raises when no library manifest is configured" do
        OpenUI::Rails.reset_configuration!

        assert_raises(ManifestError) { PromptBuilder.load }
      end

      test "load raises when the prompt file is missing" do
        OpenUI::Rails.configure do |config|
          config.library_spec_path = file_fixture("library.spec.json")
          config.prompt_path = "/nonexistent/prompt.txt"
        end

        assert_raises(ManifestError) { PromptBuilder.load }
      ensure
        OpenUI::Rails.reset_configuration!
      end
    end
  end
end
