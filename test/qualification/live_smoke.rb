# frozen_string_literal: true

# Separate process: the gem's core suite must still prove RubyLLM is optional.
require "bundler/setup"
require "minitest/autorun"
require "webmock/minitest"
require "tmpdir"
require "json"

class LiveQualificationSmokeTest < Minitest::Test
  def setup
    WebMock.disable_net_connect!
    stub_request(:get, "https://openrouter.ai/api/v1/models").to_return(body: JSON.generate(data: [ {
      id: "openai/gpt-4.1-mini", pricing: { prompt: "0.0000004", completion: "0.0000016" }
    } ]))
  end

  def invoke(output)
    previous_key, previous_args = ENV["OPENROUTER_API_KEY"], ARGV.dup
    ENV["OPENROUTER_API_KEY"] = "synthetic-key"
    ARGV.replace([ "--authorized", "--output", output ])
    load File.expand_path("../../bin/check-live", __dir__)
  ensure
    ENV["OPENROUTER_API_KEY"] = previous_key
    ARGV.replace(previous_args)
  end

  def test_one_request_streams_complete_source_without_tools_or_retries
    source = 'root = TextContent("Release readiness")'
    sse = "data: #{JSON.generate(id: 'synthetic', model: 'openai/gpt-4.1-mini',
      choices: [ { index: 0, delta: { content: source }, finish_reason: nil } ])}\n\ndata: [DONE]\n\n"
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions").with do |request|
      body = JSON.parse(request.body)
      body["max_tokens"] == 1024 && body.dig("provider", "allow_fallbacks") == false && !body.key?("tools")
    end.to_return(status: 200, headers: { "Content-Type" => "text/event-stream" }, body: sse)
    Dir.mktmpdir do |directory|
      output = File.join(directory, "attempt")
      capture_io { invoke(output) }
      assert_equal source, File.read(File.join(output, "source.openui"))
      assert_equal false, JSON.parse(File.read(File.join(output, "report.json"))).fetch("browser_verified")
      assert_equal 1, JSON.parse(File.read(File.join(output, "attempt.json"))).fetch("max_requests")
    end
    assert_requested :post, "https://openrouter.ai/api/v1/chat/completions", times: 1
  end

  def test_provider_failure_is_not_retried_and_does_not_create_success_output
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions").to_return(status: 500,
      body: JSON.generate(error: { message: "private-provider-detail", type: "server_error" }))
    Dir.mktmpdir do |directory|
      output = File.join(directory, "attempt")
      error = nil
      stdout, stderr = capture_io { error = assert_raises(SystemExit) { invoke(output) } }
      assert_equal 1, error.status
      refute_includes stdout + stderr, "private-provider-detail"
      capture_io { assert_raises(SystemExit) { invoke(output) } }
      assert File.file?(File.join(output, "attempt.json"))
      refute File.exist?(File.join(output, "source.openui"))
      refute File.exist?(File.join(output, "report.json"))
    end
    assert_requested :post, "https://openrouter.ai/api/v1/chat/completions", times: 1
  end
end
