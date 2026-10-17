# frozen_string_literal: true

module OpenUI
  module Rails
    module Actions
      # Everything an authorizer or handler needs to decide and act, without
      # handing them the raw client payload.
      Invocation = Struct.new(
        :action, :args, :actor, :surface, :tenant, :context, :submission,
        keyword_init: true
      ) do
        def message_id = context[:message_id]
      end
    end
  end
end
