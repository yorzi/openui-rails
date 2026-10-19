# frozen_string_literal: true

module SupportDesk # :nodoc:
  class ConversationsController < BaseController
    # The state endpoint uses an explicit top-level JSON contract.
    wrap_parameters false
    skip_before_action :authenticate, only: :index

    def index
    end

    def show
      conversation
    end

    def stream
      frames = conversation.generate!
      transport = OpenUI::Rails::Stream::Transports::TurboStreams.new("unused", target: "desk-envelopes")
      response.headers["Content-Type"] = "text/vnd.turbo-stream.html; charset=utf-8"
      response.headers["Cache-Control"] = "no-store"
      self.response_body = Enumerator.new do |body|
        frames.each do |frame|
          body << %(<turbo-stream action="append" target="desk-envelopes"><template>#{transport.element(frame)}</template></turbo-stream>\n)
        end
      end
    end

    def snapshot
      if conversation.response.empty?
        head :conflict
      else
        render json: conversation.snapshot.to_h
      end
    end

    def state
      record = conversation
      body = request.request_parameters
      unless (body.keys - %w[state version]).empty? && body["version"].is_a?(Integer) && body["version"] >= 0
        raise OpenUI::Rails::InvalidActionError, "invalid state request"
      end

      record.save_form!(body["state"], expected_version: body["version"])
      head :no_content
    end
  end
end
