# frozen_string_literal: true

module OpenUI
  module Rails
    # Resolves the pinned OpenUI browser runtime and the integrity metadata the
    # mount element advertises.
    #
    # The runtime is version-pinned. Self-hosted (the default) points at a file
    # the install generator vendored into the host app; the external strategy
    # requires an explicit, exact-version URL so no floating CDN range is used
    # in production.
    module RuntimeAsset
      PINNED_VERSION = "0.2.1"
      FILE_PREFIX = "openui-browser-bundle"

      class << self
        def version(configuration = OpenUI::Rails.configuration)
          configuration.runtime_version || PINNED_VERSION
        end

        def url(configuration = OpenUI::Rails.configuration)
          configuration.runtime_url || default_url(configuration)
        end

        def default_url(configuration = OpenUI::Rails.configuration)
          "#{configuration.local_runtime_path}/#{FILE_PREFIX}-#{version(configuration)}.js"
        end

        def external?(configuration = OpenUI::Rails.configuration)
          configuration.runtime_assets == :external
        end

        # The `data-openui-runtime-*` attributes merged into every mount.
        def mount_data(configuration = OpenUI::Rails.configuration)
          {
            openui_runtime_url: url(configuration),
            openui_runtime_version: version(configuration),
            openui_runtime_integrity: configuration.runtime_integrity
          }.compact
        end
      end
    end
  end
end
