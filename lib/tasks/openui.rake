# frozen_string_literal: true

namespace :openui do
  desc "Check local OpenUI setup without writes or network requests"
  task doctor: :environment do
    report = OpenUI::Rails::Doctor.new(root: ::Rails.root, routes: ::Rails.application.routes).run
    puts report
    exit 1 unless report.ok?
  end

  namespace :library do
    desc "Prepare the pinned default chat prompt and spec (pass true to overwrite)"
    task :prepare, [ :force ] => :environment do |_task, args|
      unless [ nil, "true", "false" ].include?(args[:force])
        raise OpenUI::Rails::ConfigurationError, "force must be true or false"
      end
      paths = OpenUI::Rails::DefaultLibrary.prepare(root: ::Rails.root, force: args[:force] == "true")
      paths.each { |path| puts "Prepared #{path}" }
      puts "Default library ready; commit the prompt and spec together."
    end
  end

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
