# frozen_string_literal: true

require "json"
require "digest"
require "pathname"

module OpenUI
  module Rails
    # Immutable, validated view of an OpenUI component-library manifest (the
    # `.spec.json` produced by the pinned OpenUI CLI).
    #
    # The manifest is the Gem's source of truth for *which* component library a
    # rendered response was produced against. A stable fingerprint is persisted
    # with every response so a client can detect drift instead of rendering an
    # old source with an incompatible new schema.
    class LibraryManifest
      # Guard against accidentally loading an enormous or hostile file.
      MAX_BYTES = 5 * 1024 * 1024

      # Candidate JSON keys, in priority order, for the human-readable name and
      # version. The upstream schema is not frozen, so extraction is tolerant.
      NAME_KEYS = %w[name libraryName library id].freeze
      VERSION_KEYS = %w[version libraryVersion library_version].freeze
      COLLECTION_KEYS = {
        components: %w[components],
        functions: %w[functions],
        actions: %w[actions]
      }.freeze

      class << self
        # Load and validate a manifest from disk.
        #
        # @param path [String, Pathname]
        # @return [LibraryManifest]
        # @raise [ManifestError] when the file is missing, oversized or invalid
        def load(path)
          path = Pathname(path)
          raise ManifestError, "library spec not found: #{path}" unless path.file?

          if path.size > MAX_BYTES
            raise ManifestError, "library spec too large (#{path.size} bytes)"
          end

          parse(path.read, source: path.expand_path.to_s)
        rescue Errno::ENOENT, Errno::EACCES => e
          raise ManifestError, "cannot read library spec: #{e.message}"
        end

        # Parse and validate a manifest from a JSON string.
        def parse(json, source: nil)
          raise ManifestError, "library spec must be a JSON string" unless json.is_a?(String)
          raise ManifestError, "library spec too large" if json.bytesize > MAX_BYTES

          document = JSON.parse(json)
          build(document, source: source)
        rescue JSON::ParserError => e
          raise ManifestError, "invalid library manifest JSON: #{e.message}"
        end

        # Validate an already-parsed document.
        def build(document, source: nil)
          unless document.is_a?(Hash)
            raise ManifestError, "library manifest must be a JSON object"
          end

          new(
            document: document,
            name: extract(document, NAME_KEYS),
            version: extract(document, VERSION_KEYS),
            source: source
          )
        end

        private

        def extract(document, keys)
          keys.each do |key|
            value = document[key]
            return value.to_s if value.is_a?(String) && !value.empty?
          end
          nil
        end
      end

      attr_reader :document, :name, :version, :source

      def initialize(document:, name: nil, version: nil, source: nil)
        @document = JsonValue.copy(document)
        @name = name&.dup&.freeze
        @version = version&.dup&.freeze
        @source = source&.dup&.freeze
        @canonical_json = build_canonical_json.freeze
        @digest = Digest::SHA256.hexdigest(@canonical_json).freeze
        @fingerprint = "sha256:#{@digest}".freeze
        @identifier = build_identifier.freeze
        freeze
      end

      # Full SHA-256 digest of the canonically serialized document.
      attr_reader :digest

      # Persisted, scheme-tagged fingerprint.
      attr_reader :fingerprint

      # Human-readable identifier, e.g. "support@1.2.0+1a2b3c4d5e6f".
      attr_reader :identifier

      def component_names = names_for(:components)
      def function_names = names_for(:functions)
      def action_names = names_for(:actions)

      # Constant-time comparison of fingerprints for mismatch checks.
      def matches?(other_fingerprint)
        return false if other_fingerprint.nil?

        expected = fingerprint
        return false unless expected.bytesize == other_fingerprint.to_s.bytesize

        secure_compare(expected, other_fingerprint.to_s)
      end

      def ==(other)
        other.is_a?(LibraryManifest) && other.fingerprint == fingerprint
      end
      alias eql? ==

      def hash
        fingerprint.hash
      end

      def to_h
        {
          name: name,
          version: version,
          fingerprint: fingerprint,
          source: source
        }
      end

      private

      def names_for(collection)
        keys = COLLECTION_KEYS.fetch(collection)
        keys.each do |key|
          value = document[key]
          next unless value.is_a?(Array)

          return value.filter_map { |entry| name_of(entry) }
        end
        []
      end

      def name_of(entry)
        return entry if entry.is_a?(String)

        if entry.is_a?(Hash)
          NAME_KEYS.each { |key| return entry[key].to_s if entry[key].is_a?(String) }
        end
        nil
      end

      def canonical_json
        @canonical_json
      end

      def build_canonical_json
        JSON.generate(sort_deep(document))
      rescue JSON::GeneratorError
        # Defensive: an exotic document should still fingerprint deterministically.
        JSON.generate(document)
      end

      def build_identifier
        base = [ name, version ].compact.join("@")
        base = "library" if base.empty?
        "#{base}+#{digest[0, 12]}"
      end

      def sort_deep(value)
        case value
        when Hash
          value.keys.sort_by(&:to_s).each_with_object({}) { |key, memo| memo[key] = sort_deep(value[key]) }
        when Array
          value.map { |entry| sort_deep(entry) }
        else
          value
        end
      end

      def secure_compare(left, right)
        return false unless left.bytesize == right.bytesize

        result = 0
        left.bytes.zip(right.bytes) { |a, b| result |= a ^ b }
        result.zero?
      end
    end
  end
end
