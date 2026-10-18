# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    class MessageTest < ActiveSupport::TestCase
      STORED = <<~MSG.chomp
        ]]>openui:content?library=support%401.2.0
        root = Card([title, saveBtn])
        title = TextContent("Order 42")
        saveBtn = Button("Save", @ToAssistant("Save order", {orderId: 42}))
        ]]>openui:context
        {"formState":{"note":"rush"}}
        ]]>openui:end
      MSG

      test "parses a stored message into its parts" do
        parsed = Message.parse(STORED)

        assert_equal "support@1.2.0", parsed.attributes["library"]
        assert_equal({ "note" => "rush" }, parsed.context["formState"])
        assert parsed.finished
        assert_includes parsed.content, "root = Card"
        assert_includes parsed.content, "saveBtn = Button"
      end

      test "round-trips build then parse" do
        built = Message.build(
          content: "root = TextContent(\"hi\")",
          context: { formState: { note: "rush" } },
          attributes: { library: "support@1.2.0" },
          finished: true
        )
        parsed = Message.parse(built)

        assert_equal "root = TextContent(\"hi\")", parsed.content
        assert_equal({ "formState" => { "note" => "rush" } }, parsed.context)
        assert_equal "support@1.2.0", parsed.attributes["library"]
        assert parsed.finished
      end

      test "build accepts the upstream end: keyword" do
        built = Message.build(content: "x", end: true)

        assert Message.parse(built).finished
      end

      test "build rejects unknown options" do
        assert_raises(ArgumentError) { Message.build(content: "x", nope: true) }
      end

      test "build URLSearchParams-encodes attributes" do
        built = Message.build(content: "x", attributes: { library: "support@1.2.0" })

        assert_includes built, "]]>openui:content?library=support%401.2.0"
      end

      test "build writes a string context verbatim" do
        built = Message.build(content: "x", context: "raw text")

        assert_equal "raw text", Message.parse(built).context
      end

      test "build omits the context section for nil context" do
        refute_includes Message.build(content: "x"), "]]>openui:context"
      end

      test "the last content section wins and an earlier context is ignored" do
        stored = <<~MSG.chomp
          ]]>openui:content
          first
          ]]>openui:context
          {"stale":true}
          ]]>openui:content
          second
          ]]>openui:context
          {"fresh":true}
        MSG

        parsed = Message.parse(stored)

        assert_equal "second", parsed.content
        assert_equal({ "fresh" => true }, parsed.context)
      end

      test "a context section before the content marker is ignored" do
        stored = <<~MSG.chomp
          ]]>openui:context
          {"stale":true}
          ]]>openui:content
          x
        MSG

        parsed = Message.parse(stored)

        assert_equal "x", parsed.content
        assert_nil parsed.context
      end

      test "unknown markers are skipped together with their text" do
        stored = <<~MSG.chomp
          ]]>openui:content
          visible
          ]]>openui:somethingelse
          hidden
          ]]>openui:end
        MSG

        parsed = Message.parse(stored)

        assert_equal "visible", parsed.content
        refute_includes parsed.content, "hidden"
        assert parsed.finished
      end

      test "text before the first marker is content only without a content marker" do
        stored = "intro line\n]]>openui:end"

        assert_equal "intro line", Message.parse(stored).content
      end

      test "plain text without markers is returned unchanged" do
        text = "just some prose"

        parsed = Message.parse(text)

        assert_equal text, parsed.content
        assert_nil parsed.context
        assert_equal({}, parsed.attributes)
        refute parsed.finished
      end

      test "a mid-line content marker is moved onto its own line" do
        stored = "before ]]>openui:content\nafter"

        parsed = Message.parse(stored)

        assert_equal "after", parsed.content
      end

      test "a mid-line end marker is ordinary text" do
        stored = "a ]]>openui:end b"

        assert_equal stored, Message.parse(stored).content
      end

      test "invalid JSON context is returned as raw text" do
        stored = "]]>openui:content\nx\n]]>openui:context\nnot json"

        assert_equal "not json", Message.parse(stored).context
      end

      test "streaming holds back a partial marker line" do
        stored = "]]>openui:content\nroot = Card\n]]>open"

        parsed = Message.parse(stored, streaming: true)

        assert_equal "root = Card", parsed.content
      end

      test "strip removes the markers for model history" do
        assert_equal "root = Card([title, saveBtn])\ntitle = TextContent(\"Order 42\")\nsaveBtn = Button(\"Save\", @ToAssistant(\"Save order\", {orderId: 42}))",
                     Message.strip(STORED)
        refute_includes Message.strip(STORED), "]]>openui:"
      end

        test "Parsed#to_h maps finished back to the upstream end key" do
        assert_equal true, Message.parse(STORED).to_h[:end]
        end

        test "matches upstream CRLF boundaries and preserves text after an end marker" do
          stored = "]]>openui:content\r\nfirst\r\n]]>openui:end\r\nsecond"
          parsed = Message.parse(stored)

          assert_equal "first\nsecond", parsed.content
          assert parsed.finished?
        end

        test "context is parsed only after the whole section has been accumulated" do
          stored = Message.build(content: "x", context: "1\nnot json", finished: true)
          assert_equal "1\nnot json", Message.parse(stored).context
        end

        test "invalid marker syntax is ordinary content" do
          stored = "]]>openui:content\nx\n]]>openui:something-else\ny"
          assert_equal "x\n]]>openui:something-else\ny", Message.parse(stored).content
        end
    end
  end
end
