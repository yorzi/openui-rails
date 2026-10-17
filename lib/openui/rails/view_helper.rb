# frozen_string_literal: true

module OpenUI
  module Rails
    # View helper that emits the escaped DOM mount the Stimulus controller
    # connects to. It renders no OpenUI UI itself: the browser runtime owns
    # rendering, Rails owns the opaque identifier and revision.
    module ViewHelper
      # Render a mount element for a surface.
      #
      # @param surface [Surface, #id, nil] a Surface, a host record, or nil when
      #   `response`/`id` are supplied directly
      # @param stream [Boolean] mark the surface as still streaming
      # @param options [Hash] overrides forwarded to {Surface.coerce}
      # @return [ActiveSupport::SafeBuffer]
      def openui_surface(surface = nil, stream: false, dom_id: nil, initial_state: nil, **options)
        surface ||= options.delete(:surface)
        surface = Surface.coerce(surface, **options)
        data = surface.to_mount_data(
          stream: stream,
          actions_endpoint: OpenUI::Rails.configuration.actions_endpoint,
          initial_state: initial_state
        ).merge(RuntimeAsset.mount_data)

        tag.div(
          "",
          id: dom_id || "openui-surface-#{surface.id}",
          class: "openui-surface",
          data: data
        )
      end
    end
  end
end
