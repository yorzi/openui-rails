# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "digest"

namespace :openui do
  namespace :runtime do
    desc "Vendor the pinned OpenUI browser bundle into public/openui (requires npm)"
    task fetch: :environment do
      version = OpenUI::Rails::RuntimeAsset.version
      package = "@openuidev/browser-bundle@#{version}"
      destination = ::Rails.root.join("public", "openui")
      FileUtils.mkdir_p(destination)

      Dir.mktmpdir("openui-runtime") do |tmp|
        sh "npm", "pack", package, "--pack-destination", tmp
        tarball = Dir.glob(File.join(tmp, "*.tgz")).first
        raise "npm pack produced no tarball for #{package}" if tarball.nil?

        sh "tar", "-xzf", tarball, "-C", tmp

        root = File.join(tmp, "package")
        js = Dir.glob(File.join(root, "**", "*.js")).max_by { |file| File.size(file) }
        raise "no JavaScript bundle found in #{package}" if js.nil?

        target_js = destination.join("openui-browser-bundle-#{version}.js")
        FileUtils.cp(js, target_js)
        puts "Vendored #{js} -> #{target_js}"

        css = Dir.glob(File.join(root, "**", "*.css")).max_by { |file| File.size(file) }
        if css
          target_css = destination.join("openui-browser-bundle-#{version}.css")
          FileUtils.cp(css, target_css)
          puts "Vendored #{css} -> #{target_css}"
        end
      end

      digest = Digest::SHA384.base64digest(File.binread(destination.join("openui-browser-bundle-#{version}.js")))
      puts ""
      puts "Optional integrity pin for config/initializers/openui.rb:"
      puts %(  config.runtime_integrity = "sha384-#{digest}")
    end
  end
end
