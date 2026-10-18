# frozen_string_literal: true

require "openui/rails/stream/bridge"

module OpenUI
  module Rails
    module Adapters
      # Optional RubyLLM adapter. It owns RubyLLM-specific event normalization
      # and delegates sequencing, coalescing and size limits to the Stream
      # bridge, so a host keeps using RubyLLM's own Rails streaming pattern
      # (`chat.complete { |chunk| ... }` in a job) instead of replacing it.
      #
      # `ruby_llm` is never required by the Gem and no `RubyLLM` constant is
      # referenced: failures are classified by class *name*, so this unit loads
      # and is tested without the dependency installed. The supported RubyLLM
      # version is pinned in the README compatibility matrix.
      module RubyLLM
        STRATEGIES = %i[complete ask].freeze

        class << self
          # Stream a RubyLLM completion, yielding ordered {Stream::Envelope}s.
          #
          # @param chat [#complete, #ask] a RubyLLM chat (or a duck type)
          # @param question [String] the user prompt
          # @param surface_id [String, #to_s] the target surface
          # @param strategy [Symbol] :complete (default) or :ask
          # @yieldparam envelope [Stream::Envelope]
          # @return [Stream::Bridge::Writer] for inspection in tests
          def stream(chat:, question:, surface_id:, message_id: nil, library_version: nil,
                     instruction: nil, strategy: :complete,
                     configuration: OpenUI::Rails.configuration, &block)
            raise ConfigurationError, "surface_id is required" if surface_id.nil?
            raise ConfigurationError, "a block is required" unless block
            unless STRATEGIES.include?(strategy)
              raise ConfigurationError, "unsupported strategy #{strategy.inspect}; expected one of #{STRATEGIES.inspect}"
            end

            instruction ||= PromptBuilder.load(configuration).system_instruction
            library_version ||= configuration.library_fingerprint
            chat = apply_instruction(chat, instruction)

            writer = Stream::Bridge.new(
              message_id: message_id || surface_id.to_s,
              library_version: library_version,
              configuration: configuration
            ).writer

            begin
              consumer_failed = false
              deliver = lambda do |envelope|
                begin
                  block.call(envelope)
                rescue StandardError
                  consumer_failed = true
                  raise
                end
              end
              consume(chat, question, strategy) do |chunk|
                text = normalize_chunk(chunk)
                next if text.nil?

                writer.push(text).each(&deliver)
              end
              writer.finish.each(&deliver)
            rescue StandardError => e
              raise if consumer_failed

              envelope = writer.error_for(e, code: error_code_for(e))
              block.call(envelope) if envelope
            end

            writer
          end

          private

          def apply_instruction(chat, instruction)
            return chat unless chat.respond_to?(:with_instructions)

            chat.with_instructions(instruction)
          end

          def consume(chat, question, strategy, &block)
            case strategy
            when :complete
              # RubyLLM::Chat#complete only accepts a block. A user message is
              # added explicitly; #ask is the convenient alternative strategy.
              chat.add_message(role: :user, content: question) unless question.nil?
              chat.complete(&block)
            when :ask then chat.ask(question, &block)
            end
          end

          def normalize_chunk(chunk)
            return chunk if chunk.is_a?(String)
            return nil unless chunk.respond_to?(:content)

            content = chunk.content
            content.nil? ? nil : content.to_s
          end

          def error_code_for(error)
            name = error.class.name
            return "stream_cancelled" if name == "RubyLLM::CancelledError"
            return "provider_rejected" if name&.start_with?("RubyLLM::")

            "stream_failed"
          end
        end
      end
    end
  end
end
