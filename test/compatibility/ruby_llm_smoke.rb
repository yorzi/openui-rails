# frozen_string_literal: true

# Separate process so the core unit suite can still prove RubyLLM is optional.
require "test_helper"
require "ruby_llm"
require "webmock/minitest"

class RubyLLMCompatibilityTest < ActiveSupport::TestCase
  setup do
    OpenUI::Rails.reset_configuration!
    RubyLLM.configure { |config| config.openai_api_key = "not-a-real-api-key" }
    WebMock.disable_net_connect!
  end

  teardown { OpenUI::Rails.reset_configuration! }

  test "RubyLLM 2.1.1 streams through its real OpenAI SSE parser for both strategies" do
    sse = [ "root = ", 'TextContent("Real RubyLLM")' ].map do |text|
      "data: #{JSON.generate(id: 'chat-test', object: 'chat.completion.chunk', model: 'gpt-4.1-mini',
        choices: [ { index: 0, delta: { content: text }, finish_reason: nil } ])}\n\n"
    end.join + "data: [DONE]\n\n"
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with { |request| JSON.parse(request.body).fetch("messages").any? { |message| message["content"] == "Draw a chart" } }
      .to_return(status: 200, headers: { "Content-Type" => "text/event-stream" }, body: sse)

    [ :complete, :ask ].each do |strategy|
      chat = RubyLLM.chat(model: "gpt-4.1-mini", provider: :openai, protocol: :chat_completions)
      envelopes = []
      OpenUI::Rails::Adapters::RubyLLM.stream(
        chat: chat, question: "Draw a chart", surface_id: "compatibility",
        instruction: "Render OpenUI", strategy: strategy
      ) { |envelope| envelopes << envelope }

      assert envelopes.last.completed?, envelopes.map(&:to_h).inspect
      assert_equal 'root = TextContent("Real RubyLLM")', envelopes.select(&:delta?).map(&:delta).join
      assert_equal "Render OpenUI", chat.messages.first.content
    end
    assert_requested :post, "https://api.openai.com/v1/chat/completions", times: 2
  end
end
