# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "rubygems/package"
require "tmpdir"
require "zlib"

module OpenUI
  module Rails
    # Explicit, checksum-locked upstream files. Never guess the bundle by size,
    # execute npm lifecycle scripts, or extract archive-supplied paths to disk.
    class RuntimePackage # :nodoc:
      ARCHIVE_INTEGRITY = "sha512-aGKJ9H4IY+g+RkcUFtsQPjJzGAo6qWKDI/zjCs0S55ZbA97vlfmT4H8qbXi2fgueUcbDfY31RMicl1W0Vu9+2A=="
      FILES = {
        "package/dist/openui-bundle.min.js" => [ "js", "sha384-GNNBzicRNkuscleA9e7/4cz6JwE9PE4BRKJ1udKWNzBh4DTD2/zpfOz4p91n8sW0" ],
        "package/dist/openui-styles.css" => [ "css", "sha384-A2WnfysZ4D3GKsh9QIb/3l0NpcRI4dymzzey3lw1S+iOCb0oRr5rmGRSi2V2DNlp" ],
        "package/LICENSE" => [ "LICENSE.txt", "sha384-SUod7wLZUpknLntRqnhPU64j18MNc2M7sL+voImaQG/xeoejQ7iIStmQy1ovv64o" ]
      }.freeze

      def self.fetch(destination:, version: RuntimeAsset::PINNED_VERSION)
        unless version == RuntimeAsset::PINNED_VERSION
          raise ConfigurationError, "runtime fetch only supports checksum-locked version #{RuntimeAsset::PINNED_VERSION}"
        end

        Dir.mktmpdir("openui-runtime") do |directory|
          _output, error, status = Open3.capture3("npm", "pack", "@openuidev/browser-bundle@#{version}",
            "--ignore-scripts", "--pack-destination", directory)
          raise ConfigurationError, "npm pack failed: #{error}" unless status.success?

          archives = Dir.glob(File.join(directory, "*.tgz"))
          raise ConfigurationError, "npm pack did not produce exactly one archive" unless archives.size == 1

          new.install(archives.first, destination: destination)
        end
      end

      def install(archive, destination:)
        verify!(File.binread(archive), ARCHIVE_INTEGRITY)
        files = {}
        Zlib::GzipReader.open(archive) do |gzip|
          Gem::Package::TarReader.new(gzip) do |tar|
            tar.each do |entry|
              next unless FILES.key?(entry.full_name)
              raise ConfigurationError, "runtime archive entry is not a regular file" unless entry.file?

              suffix, integrity = FILES.fetch(entry.full_name)
              content = entry.read
              verify!(content, integrity)
              files[suffix] = content
            end
          end
        end
        raise ConfigurationError, "runtime archive is missing expected files" unless files.size == FILES.size

        FileUtils.mkdir_p(destination)
        files.map do |suffix, content|
          path = File.join(destination, "#{RuntimeAsset::FILE_PREFIX}-#{RuntimeAsset::PINNED_VERSION}.#{suffix}")
          File.binwrite(path, content)
          path
        end
      end

      private

      def verify!(content, expected)
        algorithm, _digest = expected.split("-", 2)
        actual = "#{algorithm}-#{Digest.const_get(algorithm.upcase).base64digest(content)}"
        raise ConfigurationError, "runtime integrity verification failed" unless actual == expected
      end
    end
  end
end
