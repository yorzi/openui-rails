# frozen_string_literal: true

namespace :openui do
  namespace :runtime do
    desc "Vendor the checksum-locked OpenUI JS, CSS and license (requires npm)"
    task :fetch, [ :destination ] => :environment do |_task, args|
      configuration = OpenUI::Rails.configuration
      destination = args[:destination] || ::Rails.root.join("public", configuration.local_runtime_path.delete_prefix("/"))
      paths = OpenUI::Rails::RuntimePackage.fetch(
        destination: destination, version: OpenUI::Rails::RuntimeAsset.version(configuration)
      )
      paths.each { |path| puts "Vendored #{path}" }
      puts "Checksums verified; include <%= openui_stylesheet_tag %> in your layout."
    end
  end
end
