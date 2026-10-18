# frozen_string_literal: true

require "fileutils"
require "tempfile"

module OpenUI
  module Rails
    # Task implementation for installing exports of the pinned default library.
    class DefaultLibrary # :nodoc:
      DIRECTORY = File.expand_path("default_library", __dir__)
      NAMES = %w[library.spec.json library.prompt.txt openui.LICENSE.txt].freeze

      def self.files(directory: DIRECTORY)
        provenance = JSON.parse(File.read(File.join(directory, "provenance.json")))
        integrity = RuntimePackage::FILES.fetch("package/dist/openui-bundle.min.js").last
        unless provenance.fetch("runtime_version") == RuntimeAsset::PINNED_VERSION && provenance.fetch("runtime_integrity") == integrity
          raise ConfigurationError, "default library exports do not match the pinned runtime"
        end

        NAMES.to_h do |name|
          content = File.binread(File.join(directory, name))
          unless Digest::SHA256.hexdigest(content) == provenance.fetch("sha256").fetch(name)
            raise ConfigurationError, "default library export checksum mismatch; reinstall the gem"
          end
          [ name, content ]
        end
      rescue JSON::ParserError, KeyError, SystemCallError
        raise ConfigurationError, "default library exports are unavailable or invalid; reinstall the gem"
      end

      def self.prepare(root:, configuration: OpenUI::Rails.configuration, force: false)
        root = File.realpath(root)
        exports = files
        targets = [ configuration.library_spec_path, configuration.prompt_path ].map { |path| safe_path(path, root) }
        targets << safe_path(File.join(File.dirname(targets.last), "openui.LICENSE.txt"), root)
        if targets.uniq.size != targets.size || targets.any? { |path| targets.any? { |other| path.start_with?("#{other}/") } }
          raise ConfigurationError, "prompt and spec need distinct file paths"
        end
        contents = targets.zip(NAMES.map { |name| exports.fetch(name) }).to_h
        if !force && contents.any? { |path, content| File.exist?(path) && File.binread(path) != content }
          raise ConfigurationError, "existing library files differ; preserve your custom library or explicitly use openui:library:prepare[true]"
        end

        contents.each do |path, content|
          next if File.file?(path) && File.binread(path) == content

          FileUtils.mkdir_p(File.dirname(path))
          Tempfile.create(".openui-library-", File.dirname(path)) do |temporary|
            temporary.chmod(0o644)
            temporary.binmode
            temporary.write(content)
            temporary.flush
            if force
              File.rename(temporary.path, path)
            else
              File.link(temporary.path, path)
            end
          end
        end
        configuration.reset!
        targets
      rescue Errno::EEXIST
        raise ConfigurationError, "library file appeared during preparation; rerun without overwriting it"
      end

      def self.safe_path(path, root)
        raise ConfigurationError, "configure both library_spec_path and prompt_path before preparing the library" if path.nil?

        target = File.expand_path(path, root)
        unless !File.symlink?(target) && (!File.exist?(target) || File.file?(target))
          raise ConfigurationError, "library outputs must be regular files inside the application root"
        end

        ancestor = File.dirname(target)
        ancestor = File.dirname(ancestor) until File.exist?(ancestor) || File.symlink?(ancestor)
        real = File.realpath(ancestor)
        unless File.directory?(ancestor) && (real == root || real.start_with?("#{root}/"))
          raise ConfigurationError, "library output directory resolves outside the application root"
        end
        File.join(real, target.delete_prefix(ancestor).delete_prefix("/"))
      end
      private_class_method :safe_path
    end
  end
end
