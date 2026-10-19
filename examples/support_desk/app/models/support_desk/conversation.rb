# frozen_string_literal: true

module SupportDesk # :nodoc:
  # Host-owned state and business transactions, outside the gem's public API.
  class Conversation < ActiveRecord::Base
    belongs_to :user
    belongs_to :ticket

    def message_id = "desk-#{id}-turn-#{version}"

    def surface
      OpenUI::Rails::Surface.new(
        id: id, version: version, message_id: message_id, response: response,
        library_version: OpenUI::Rails.configuration.library_fingerprint,
        next_sequence: next_sequence, completed: response.present?, streaming: response.empty?, context: form_state
      )
    end

    # Persist canonical output before delivery. A disconnect cannot erase it.
    # This deterministic fixture substitutes for a provider, not for the renderer.
    def generate!
      with_lock do
        return [ snapshot ] if response.present?

        source = <<~LANG
          ticket = Query("ticket_lookup", {}, {title: "Loading ticket", status: "loading"})
          close = Mutation("close_ticket", {})
          note = FormControl("Private note", Input("note", "Write a note"))
          replyButtons = Buttons([Button("Continue conversation", @ToAssistant("Review this ticket"))])
          reply = Form("reply", replyButtons, [note])
          controls = Buttons([Button("Close ticket", @Run(close))])
          root = Card([CardHeader("Support ticket"), TextContent(ticket.title), TextContent(ticket.status), TextContent("Conversation turns: #{messages.length}"), reply, controls])
        LANG
        config = OpenUI::Rails::Configuration.new
        config.pending_byte_limit = 1
        frames = OpenUI::Rails::Stream::Bridge.new(message_id: message_id,
          library_version: OpenUI::Rails.configuration.library_fingerprint, configuration: config).envelopes(source.lines).to_a
        update!(response: source, next_sequence: frames.last.sequence + 1)
        frames
      end
    end

    def snapshot
      OpenUI::Rails::Stream::Envelope.snapshot(message_id: message_id,
        sequence: next_sequence - 1, response: response,
        library_version: OpenUI::Rails.configuration.library_fingerprint)
    end

    def self.valid_form_state?(state)
      state.is_a?(Hash) &&
        (state.keys - [ "reply" ]).empty? && state.values.all? { |fields|
          fields.is_a?(Hash) && (fields.keys - [ "note" ]).empty? && fields.values.all? { |field|
            field.is_a?(Hash) && (field.keys - %w[value componentType]).empty? &&
              field["value"].is_a?(String) && field["value"].bytesize <= 2000 &&
              (!field.key?("componentType") || field["componentType"] == "Input")
          }
        } && JSON.generate(state).bytesize <= 4096
    end

    def save_form!(state, expected_version:)
      raise OpenUI::Rails::InvalidActionError, "invalid note state" unless self.class.valid_form_state?(state)

      with_lock do
        check_version!(expected_version)
        update!(form_state: state)
      end
    end

    def close_ticket!(invocation)
      with_lock do
        check_version!(invocation.submission.version)
        raise OpenUI::Rails::InvalidActionError, "ticket is already closed" if ticket.reload.status == "closed"

        Receipt.create!(ticket_id: ticket_id, operation: "close")
        ticket.update!(status: "closed")
        advance!
      end
      { "version" => version, "status" => "closed" }
    end

    def continue!(invocation)
      with_lock do
        check_version!(invocation.submission.version)
        raise OpenUI::Rails::InvalidActionError, "demo turn limit reached" if messages.length >= 20

        update!(messages: messages + [ { "role" => "user", "text" => invocation.args.fetch("message") } ],
          form_state: invocation.args.fetch("form_state", form_state))
        advance!
      end
      { "version" => version }
    end

    private

    def check_version!(expected)
      raise OpenUI::Rails::StaleSurfaceError, "conversation changed; reload it" unless version == expected
    end

    def advance!
      update!(version: version + 1, response: "", next_sequence: 0)
    end
  end
end
