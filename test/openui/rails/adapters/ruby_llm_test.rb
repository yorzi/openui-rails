# frozen_string_literal: true

require "test_helper"

# Simulate RubyLLM's class names without installing the optional dependency,
# so adapter error classification is exercised for real.
module RubyLLM
  class Error < StandardError; end
  class CancelledError < Error; end
end

module OpenUI
  module Rails
    module Adapters
      class RubyLLMTest < ActiveSupport::TestCase
        Chunk = Struct.new(:content)

        class FakeChat
          attr_reader :question, :instructions

          def initialize(chunks)
            @chunks = chunks
          end

          def complete(question = nil)
            @question = question
            @chunks.each { |chunk| yield chunk }
          end

          def with_instructions(text)
            @instructions = text
            self
          end
        end

        class FailingChat
          def initialize(error)
            @error = error
          end

          def complete(*)
            yield Chunk.new("partial")
            raise @error
          end
        end

        setup do
          OpenUI::Rails.reset_configuration!
          OpenUI::Rails.configure do |config|
            config.library_spec_path = file_fixture("library.spec.json")
            config.prompt_path = file_fixture("library.prompt.txt")
            config.pending_byte_limit = 1024
          end
        end

        teardown { OpenUI::Rails.reset_configuration! }

        def collect(chat, **options)
          envelopes = []
          OpenUI::Rails::Adapters::RubyLLM.stream(
            chat: chat, question: "Draw a chart", surface_id: "surface-1", **options
          ) { |envelope| envelopes << envelope }
          envelopes
        end

        test "streams deltas then a completion" do
          chat = FakeChat.new([ Chunk.new("root = "), Chunk.new("Card()") ])

          envelopes = collect(chat)

          assert_equal [ "root = Card()" ], envelopes.select(&:delta?).map(&:delta)
          assert envelopes.last.completed?
          assert envelopes.all? { |envelope| envelope.message_id == "surface-1" }
        end

        test "applies the generated system instruction" do
          chat = FakeChat.new([])

          collect(chat)

          assert_includes chat.instructions, "Support library"
        end

        test "forwards the question and passes the library fingerprint" do
          chat = FakeChat.new([])

          envelopes = collect(chat)
          manifest = OpenUI::Rails.configuration.library_manifest

          assert_equal "Draw a chart", chat.question
          assert envelopes.all? { |envelope| envelope.library_version == manifest.fingerprint }
        end

        test "accepts string chunks and skips empty content" do
          chat = FakeChat.new([ "a", Chunk.new(nil), Chunk.new("b") ])

          envelopes = collect(chat)

          assert_equal [ "ab" ], envelopes.select(&:delta?).map(&:delta)
        end

        test "an explicit instruction and message id override the defaults" do
          chat = FakeChat.new([])

          envelopes = collect(chat, instruction: "custom", message_id: "msg-9")

          assert_equal "custom", chat.instructions
          assert envelopes.all? { |envelope| envelope.message_id == "msg-9" }
        end

        test "classifies a provider failure as a structured error" do
          envelopes = collect(FailingChat.new(::RubyLLM::Error.new("provider down")))

          assert envelopes.last.error?
          assert_equal "provider_rejected", envelopes.last.code
          refute_includes envelopes.last.to_h.to_s, "provider down"
        end

        test "classifies cancellation distinctly" do
          envelopes = collect(FailingChat.new(::RubyLLM::CancelledError.new))

          assert_equal "stream_cancelled", envelopes.last.code
        end

        test "requires a surface id and a block" do
          chat = FakeChat.new([])

          assert_raises(ConfigurationError) do
            OpenUI::Rails::Adapters::RubyLLM.stream(chat: chat, question: "x", surface_id: nil) { }
          end
          assert_raises(ConfigurationError) do
            OpenUI::Rails::Adapters::RubyLLM.stream(chat: chat, question: "x", surface_id: "s")
          end
        end

        test "rejects an unknown strategy" do
          chat = FakeChat.new([])

          assert_raises(ConfigurationError) do
            OpenUI::Rails::Adapters::RubyLLM.stream(
              chat: chat, question: "x", surface_id: "s", strategy: :telepathy
            ) { }
          end
        end
      end
    end
  end
end
