# frozen_string_literal: true

module OpenUI
  module Rails
    # Internal canonical JSON copy. Never freezes caller-owned values or lets
    # mutable input change a fingerprint after validation.
    module JsonValue
      def self.copy(value, depth = 0)
        raise ArgumentError, "JSON nesting exceeds 100 levels" if depth > 100

        case value
        when Hash
          pairs = value.map do |key, entry|
            raise ArgumentError, "JSON object keys must be strings or symbols" unless key.is_a?(String) || key.is_a?(Symbol)

            [ key.to_s, entry ]
          end
          raise ArgumentError, "duplicate JSON object keys" unless pairs.map(&:first).uniq.size == pairs.size

          pairs.sort_by(&:first).to_h.transform_values { |entry| copy(entry, depth + 1) }.freeze
        when Array then value.map { |entry| copy(entry, depth + 1) }.freeze
        when String then value.dup.freeze
        when Integer, TrueClass, FalseClass, NilClass then value
        when Float
          raise ArgumentError, "JSON numbers must be finite" unless value.finite?

          value
        else raise ArgumentError, "unsupported JSON value #{value.class}"
        end
      end
    end
  end
end
