# frozen_string_literal: true

require "test_helper"
require "tempfile"

module OpenUI
  module Rails
    class LibraryManifestTest < ActiveSupport::TestCase
      DOCUMENT = {
        "name" => "support",
        "version" => "1.2.0",
        "components" => [
          { "name" => "Card" },
          { "name" => "Table" },
          "Chart"
        ],
        "functions" => [ { "name" => "Query" } ],
        "actions" => [ "refresh" ]
      }.freeze

      test "parses a valid manifest" do
        manifest = LibraryManifest.parse(JSON.generate(DOCUMENT))

        assert_equal "support", manifest.name
        assert_equal "1.2.0", manifest.version
      end

      test "extracts component, function and action names" do
        manifest = LibraryManifest.build(DOCUMENT)

        assert_equal %w[Card Table Chart], manifest.component_names
        assert_equal %w[Query], manifest.function_names
        assert_equal %w[refresh], manifest.action_names
      end

      test "fingerprint is stable regardless of key order" do
        reordered = JSON.parse(JSON.generate(DOCUMENT))
        reordered = reordered.to_a.reverse.to_h

        assert_equal LibraryManifest.build(DOCUMENT).fingerprint,
                     LibraryManifest.build(reordered).fingerprint
      end

      test "fingerprint changes when content changes" do
        changed = DOCUMENT.merge("version" => "1.2.1")

        refute_equal LibraryManifest.build(DOCUMENT).fingerprint,
                     LibraryManifest.build(changed).fingerprint
      end

      test "fingerprint is scheme tagged and identifier is readable" do
        manifest = LibraryManifest.build(DOCUMENT)

        assert_match(%r{\Asha256:[0-9a-f]{64}\z}, manifest.fingerprint)
        assert_match(%r{\Asupport@1\.2\.0\+[0-9a-f]{12}\z}, manifest.identifier)
      end

      test "falls back to a generic identifier without name/version" do
        manifest = LibraryManifest.build({ "components" => [] })

        assert_match(%r{\Alibrary\+[0-9a-f]{12}\z}, manifest.identifier)
      end

      test "matches? compares fingerprints and tolerates nil" do
        manifest = LibraryManifest.build(DOCUMENT)

        assert manifest.matches?(manifest.fingerprint)
        refute manifest.matches?("sha256:deadbeef")
        refute manifest.matches?(nil)
      end

      test "equality is based on the fingerprint" do
        assert_equal LibraryManifest.build(DOCUMENT), LibraryManifest.build(DOCUMENT)
        refute_equal LibraryManifest.build(DOCUMENT), LibraryManifest.build(DOCUMENT.merge("version" => "2"))
      end

      test "the document is deeply frozen" do
        manifest = LibraryManifest.build(DOCUMENT)

        assert manifest.document.frozen?
        assert manifest.document["components"].frozen?
        assert manifest.document["components"].first.frozen?
      end

      test "rejects JSON that is not an object" do
        assert_raises(ManifestError) { LibraryManifest.parse("[]") }
      end

      test "rejects invalid JSON" do
        assert_raises(ManifestError) { LibraryManifest.parse("{not json") }
      end

      test "rejects a missing file" do
        assert_raises(ManifestError) { LibraryManifest.load("/nonexistent/library.spec.json") }
      end

      test "rejects an oversized file" do
        Tempfile.create([ "library", ".json" ]) do |file|
          file.write("x" * (LibraryManifest::MAX_BYTES + 1))
          file.flush

          assert_raises(ManifestError) { LibraryManifest.load(file.path) }
        end
      end

      test "loads a valid file and records its source" do
        Tempfile.create([ "library", ".json" ]) do |file|
          file.write(JSON.generate(DOCUMENT))
          file.flush

          manifest = LibraryManifest.load(file.path)

          assert_equal "support", manifest.name
          assert_equal File.expand_path(file.path), manifest.source
        end
      end
    end
  end
end
