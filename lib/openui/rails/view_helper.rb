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
      # @param label [String, nil] accessible name; when given the mount is
      #   exposed as a `region` landmark so assistive tech can find it
      # @param options [Hash] overrides forwarded to {Surface.coerce}
      # @return [ActiveSupport::SafeBuffer]
      def openui_surface(surface = nil, stream: false, dom_id: nil, initial_state: nil, label: nil, **options)
        surface ||= options.delete(:surface)
        surface = Surface.coerce(surface, **options)
        data = surface.to_mount_data(
          stream: stream,
          actions_endpoint: OpenUI::Rails.configuration.actions_endpoint,
          initial_state: initial_state
        ).merge(RuntimeAsset.mount_data)

        # `aria-busy` tells assistive tech the region is still being updated, so
        # a streaming surface is not announced mid-flight. The controller keeps
        # it in sync as envelopes complete.
        aria = { busy: surface.streaming? || stream }
        aria[:label] = label if label

        tag.div(
          "",
          id: dom_id || "openui-surface-#{surface.id}",
          class: "openui-surface",
          role: label ? "region" : nil,
          data: data,
          aria: aria
        )
      end
    end
  end
end
