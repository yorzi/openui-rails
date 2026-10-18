# frozen_string_literal: true

module OpenUI
  module Rails
    # View helper that emits the escaped DOM mount the Stimulus controller
    # connects to. It renders no OpenUI UI itself: the browser runtime owns
    # rendering, Rails owns the opaque identifier and revision.
    module ViewHelper
      # Include once in the host layout's head. The pinned bundle requires its
      # stylesheet; it is not injected by JavaScript or repeated per surface.
      def openui_stylesheet_tag
        stylesheet_link_tag RuntimeAsset.stylesheet_url,
          integrity: RuntimeAsset.stylesheet_integrity, crossorigin: "anonymous"
      end

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
        fingerprint = OpenUI::Rails.configuration.library_fingerprint
        if fingerprint && surface.library_version && fingerprint != surface.library_version
          raise LibraryVersionError, "surface targets a different library; regenerate it with the configured library"
        end
        data = surface.to_mount_data(
          stream: stream,
          actions_endpoint: OpenUI::Rails.configuration.actions_endpoint,
          initial_state: initial_state
        ).merge(RuntimeAsset.mount_data)
        data[:openui_library_fingerprint] = fingerprint if fingerprint

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
