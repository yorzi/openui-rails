# frozen_string_literal: true

module OpenUI
  module Rails
    # Base class for every error raised by openui-rails. Rescuing
    # `OpenUI::Rails::Error` rescues the whole taxonomy.
    class Error < StandardError; end

    # Raised when configuration is invalid or an unsupported option is set.
    class ConfigurationError < Error; end

    # Raised when a library manifest cannot be loaded, parsed or validated.
    class ManifestError < Error; end

    # Raised when a browser-rendered response targets a library version that
    # does not match the pinned library fingerprint.
    class LibraryVersionError < Error; end

    # Raised when an action name is not present in the registry.
    class UnknownActionError < Error; end

    # Raised when the host authorizer denies an action.
    class UnauthorizedActionError < Error; end

    # Raised when an action payload fails schema/presence validation.
    class InvalidActionError < Error; end

    # Raised when a submitted action targets a surface revision that is no
    # longer current.
    class StaleSurfaceError < Error; end

    # Raised when an action submission replays a known idempotency key.
    class ReplayError < Error; end

    # Raised for malformed or unsafe stream payloads.
    class StreamError < Error; end

    # Raised when a caller requests an unsupported protocol/library version.
    class UnsupportedVersionError < Error; end
  end
end
