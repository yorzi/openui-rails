# frozen_string_literal: true

module OpenUI
  module Rails
    # Read-only task diagnostics. Never executes application authorization,
    # makes HTTP requests, or prints file contents and exception messages.
    class Doctor # :nodoc:
      Check = Struct.new(:name, :status, :message, keyword_init: true)
      Report = Struct.new(:checks, keyword_init: true) do
        def ok? = checks.none? { |check| check.status == :fail }

        def to_s
          lines = checks.map { |check| "[#{check.status.to_s.upcase}] #{check.name}: #{check.message}" }
          lines << (ok? ? "Required local checks passed. Review all UNVERIFIED checks." : "Setup has required failures. Fix them and rerun openui:doctor.")
          lines.join("\n")
        end
      end

      def initialize(root:, configuration: OpenUI::Rails.configuration, routes:)
        @root = File.expand_path(root)
        @configuration = configuration
        @routes = routes
      end

      def run
        @checks = []
        valid = check_configuration
        check_route
        check_assets
        check_library_identity if valid
        record("browser", :unverified, "Verify Stimulus registration, rendering, stylesheet loading, and event handling in a browser.")
        record("authorization", :unverified, "Review actor resolution, tenant-scoped surfaces, and global or per-action authorizers. Callbacks were not executed; missing authorization denies actions.")
        record("idempotency", :unverified, "Verify atomic shared storage for multiple workers, TTL limits, and business constraints.")
        record("recovery", :unverified, "Verify authorized subscriptions, canonical snapshots, and host-owned fallback UI.")
        Report.new(checks: @checks.freeze)
      end

      private

      def record(name, status, message)
        @checks << Check.new(name: name, status: status, message: message).freeze
      end

      def check_configuration
        @configuration.validate!
        prompt = @configuration.prompt_path
        raise ConfigurationError if prompt.nil? || !File.file?(prompt) || File.zero?(prompt)

        record("configuration", :pass, "Library files and numeric limits are valid.")
        true
      rescue OpenUI::Rails::Error, SystemCallError, ArgumentError, TypeError
        record("configuration", :fail, "Review library paths, nonempty prompt, manifest JSON, asset settings, and numeric limits. For the default library, run openui:library:prepare.")
        false
      end

      def check_route
        endpoint = @configuration.actions_endpoint
        raise ConfigurationError unless endpoint.is_a?(String) && endpoint.start_with?("/") && !endpoint.start_with?("//") && !endpoint.match?(/[?#]/)

        raise ConfigurationError unless endpoint.end_with?("/actions")

        mounts = @routes.routes.select { |route| route.app.respond_to?(:app) && route.app.app == Engine }
        mount_path = endpoint.delete_suffix("/actions")
        mount_path = "/" if mount_path.empty?
        matching = mounts.any? do |route|
          route.path.spec.to_s == mount_path && (route.verb.empty? || route.verb.include?("POST"))
        end
        if matching
          record("actions route", :pass, "Static engine mount matches actions_endpoint. Request constraints were not executed.")
        elsif mounts.any? { |route| route.path.spec.to_s.match?(/[:*]/) }
          record("actions route", :unverified, "The engine has a dynamic mount. Verify actions_endpoint and request constraints in the host.")
        else
          raise ConfigurationError
        end
      rescue OpenUI::Rails::Error, ArgumentError
        record("actions route", :fail, "Mount OpenUI::Rails::Engine and match actions_endpoint to that mount's /actions path.")
      end

      def default_assets?
        @configuration.runtime_assets == :self_hosted && @configuration.runtime_url.nil?
      end

      def check_assets
        unless default_assets? && @configuration.runtime_stylesheet_url.nil?
          urls = [ RuntimeAsset.url(@configuration), RuntimeAsset.stylesheet_url(@configuration) ]
          hashes = [ RuntimeAsset.integrity(@configuration), RuntimeAsset.stylesheet_integrity(@configuration) ]
          raise ConfigurationError unless urls.all? { |url| url.is_a?(String) && !url.empty? } &&
            hashes.all? { |value| value.is_a?(String) && value.match?(/\Asha(?:256|384|512)-[A-Za-z0-9+\/=]+\z/) }

          record("runtime assets", :unverified, "Custom or external URLs and integrity settings exist. No network request or content verification was performed.")
          return
        end

        raise ConfigurationError unless RuntimeAsset.version(@configuration) == RuntimeAsset::PINNED_VERSION

        public_root = File.join(@root, "public")
        url = @configuration.local_runtime_path
        raise ConfigurationError unless url.is_a?(String) && url.start_with?("/") && !url.match?(/[?#]/)

        directory = File.expand_path(url.delete_prefix("/"), public_root)
        raise ConfigurationError unless directory.start_with?("#{public_root}/")

        RuntimePackage::FILES.each_value do |suffix, expected|
          path = File.join(directory, "#{RuntimeAsset::FILE_PREFIX}-#{RuntimeAsset::PINNED_VERSION}.#{suffix}")
          inside = File.file?(path) && File.realpath(path).start_with?("#{File.realpath(@root)}/public/")
          verified = inside && "sha384-#{Digest::SHA384.file(path).base64digest}" == expected
          sri = case suffix
          when "js" then RuntimeAsset.integrity(@configuration)
          when "css" then RuntimeAsset.stylesheet_integrity(@configuration)
          else expected
          end
          verified &&= valid_integrity?(path, sri)
          record("runtime #{suffix}", verified ? :pass : :fail,
            verified ? "Matches the pinned checksum and configured integrity." : "Missing asset, checksum mismatch, or incorrect integrity override. Run openui:runtime:fetch and review integrity settings.")
        end
      rescue OpenUI::Rails::Error, SystemCallError, ArgumentError, TypeError
        record("runtime assets", :fail, "Review runtime version, paths, URLs, stylesheet, and integrity hashes. Keep default assets inside public/ and run openui:runtime:fetch.")
      end

      def valid_integrity?(path, value)
        return false unless value.is_a?(String) && value.match?(/\Asha(?:256|384|512)-[A-Za-z0-9+\/=]+\z/)

        algorithm = value.split("-", 2).first
        "#{algorithm}-#{Digest.const_get(algorithm.upcase).file(path).base64digest}" == value
      end

      def check_library_identity
        unless default_assets?
          record("library identity", :unverified, "Verify the configured prompt/spec against the actual custom runtime library.")
          return
        end

        files = DefaultLibrary.files
        matching = @configuration.library_fingerprint == LibraryManifest.parse(files.fetch("library.spec.json")).fingerprint &&
          File.binread(@configuration.prompt_path) == files.fetch("library.prompt.txt")
        record("library identity", matching ? :pass : :fail,
          matching ? "Prompt and spec match the pinned default chat library." : "The default runtime needs its matching prompt/spec. Preserve custom files or use openui:library:prepare; custom libraries need a matching custom runtime.")
      rescue OpenUI::Rails::Error, SystemCallError, ArgumentError, TypeError
        record("library identity", :fail, "Cannot verify the pinned default library exports. Review the gem installation and configured files.")
      end
    end
  end
end
