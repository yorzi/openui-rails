# frozen_string_literal: true

require "openui/rails/actions/schema"
require "openui/rails/actions/registry"
require "openui/rails/actions/submission"
require "openui/rails/actions/invocation"
require "openui/rails/actions/idempotency/memory_store"
require "openui/rails/actions/dispatcher"

module OpenUI
  module Rails
    # Server-authoritative action loop: an allowlist registry, arg validation,
    # a host authorizer, stale-surface protection and idempotency, shared by
    # both component actions and browser tool calls.
    module Actions
    end
  end
end
