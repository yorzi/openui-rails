# frozen_string_literal: true

module OpenUI
  module Rails
    # Internal: resolves the pinned OpenUI browser runtime and the integrity
    # metadata the mount element advertises. Configure assets through
    # {Configuration}; this module is not part of the supported API.
    #
    # The runtime is version-pinned. Self-hosted (the default) points at a file
    # the install generator vendored into the host app; the external strategy
    # requires an explicit, exact-version URL so no floating CDN range is used
    # in production.
    module RuntimeAsset # :nodoc:
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

        def stylesheet_url(configuration = OpenUI::Rails.configuration)
          return configuration.runtime_stylesheet_url if configuration.runtime_stylesheet_url
          if external?(configuration)
            raise ConfigurationError, "external runtime requires runtime_stylesheet_url"
          end

          "#{configuration.local_runtime_path}/#{FILE_PREFIX}-#{version(configuration)}.css"
        end

        def integrity(configuration = OpenUI::Rails.configuration)
          configuration.runtime_integrity || (default_runtime?(configuration) ? RuntimePackage::FILES.fetch("package/dist/openui-bundle.min.js").last : nil)
        end

        def stylesheet_integrity(configuration = OpenUI::Rails.configuration)
          configuration.runtime_stylesheet_integrity || (default_runtime?(configuration) ? RuntimePackage::FILES.fetch("package/dist/openui-styles.css").last : nil)
        end

        def default_runtime?(configuration)
          !external?(configuration) && !configuration.runtime_url && version(configuration) == PINNED_VERSION
        end

        def external?(configuration = OpenUI::Rails.configuration)
          configuration.runtime_assets == :external
        end

        # The `data-openui-runtime-*` attributes merged into every mount.
        def mount_data(configuration = OpenUI::Rails.configuration)
          {
            openui_runtime_url: url(configuration),
            openui_runtime_version: version(configuration),
            openui_runtime_integrity: integrity(configuration)
          }.compact
        end
      end
    end
  end
end
