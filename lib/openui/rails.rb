# frozen_string_literal: true

require "openui/rails/version"

module OpenUI
  # Rails integration for Thesys OpenUI Lang.
  #
  # This is an *unofficial* integration: it does not port or fork the OpenUI
  # parser/renderer, it wires the official, version-pinned JavaScript runtime
  # into a Rails engine and keeps Rails authoritative for auth, tenancy and
  # persistence.
  module Rails
  end
end

require "openui/rails/errors"
require "openui/rails/library_manifest"
require "openui/rails/prompt_builder"
require "openui/rails/message"
require "openui/rails/stream/envelope"
require "openui/rails/stream/accumulator"
require "openui/rails/stream/bridge"
require "openui/rails/actions"
require "openui/rails/adapters/ruby_llm"
require "openui/rails/surface"
require "openui/rails/view_helper"
require "openui/rails/configuration"
require "openui/rails/engine"
