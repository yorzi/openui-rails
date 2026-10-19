# frozen_string_literal: true

# Explicit reference-host wiring, not a generator and not a general installer.
require "fileutils"
root = File.realpath(ARGV.fetch(0, Dir.pwd))
application = File.join(root, "config/application.rb")
source = File.read(application)
marker = "Bundler.require(*Rails.groups)"
abort "expected a generated full-stack Rails host" unless source.include?(marker)
line = 'require File.join(Gem.loaded_specs.fetch("openui-rails").full_gem_path, "examples/support_desk/boot")'
File.write(application, source.sub(marker, "#{marker}\n#{line}")) unless source.include?(line)
routes = File.join(root, "config/routes.rb")
route = 'Rails.application.routes.draw { mount SupportDesk::Engine => "/support" }'
File.open(routes, "a") { |file| file.puts route } unless File.read(routes).include?("SupportDesk::Engine")
puts "Reference host wired. Install migrations, prepare the default library/runtime, and seed synthetic records as documented."
