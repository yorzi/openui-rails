# frozen_string_literal: true

require "active_support/deprecation"
require "openui/rails/version"

module OpenUI
  # Rails integration for Thesys OpenUI Lang.
  #
  # This is an *unofficial* integration: it does not port or fork the OpenUI
  # parser/renderer, it wires the official, version-pinned JavaScript runtime
  # into a Rails engine and keeps Rails authoritative for auth, tenancy and
  # persistence.
  module Rails
    # Deprecator for APIs removed in openui-rails 1.0. The engine registers it
    # in `Rails.application.deprecators`, so host deprecation settings apply.
    #
    # @return [ActiveSupport::Deprecation]
    def self.deprecator
      @deprecator ||= ActiveSupport::Deprecation.new("1.0", "openui-rails")
    end
  end
end

require "openui/rails/errors"
require "openui/rails/instrumentation"
require "openui/rails/json_value"
require "openui/rails/library_manifest"
require "openui/rails/prompt_builder"
require "openui/rails/message"
require "openui/rails/stream/envelope"
require "openui/rails/stream/accumulator"
require "openui/rails/stream/bridge"
require "openui/rails/stream/broadcaster"
require "openui/rails/stream/transports"
require "openui/rails/actions"
require "openui/rails/adapters/ruby_llm"
require "openui/rails/runtime_asset"
require "openui/rails/runtime_package"
require "openui/rails/default_library"
require "openui/rails/surface"
require "openui/rails/view_helper"
require "openui/rails/configuration"
require "openui/rails/doctor"
require "openui/rails/engine"
