# frozen_string_literal: true

# Copied into a temporary generated host by bin/smoke-package. Application
# prompt/spec files come only from the installed gem's preparation task.
require_relative "config/environment"
require "capybara/dsl"
require "selenium-webdriver"

abort "browser loaded the source checkout" unless Gem.loaded_specs.fetch("openui-rails").full_gem_path == ARGV.fetch(0)
ActionController::Base.allow_forgery_protection = true
OpenUI::Rails.actions.register("continue_conversation", handler: ->(_) { { "message" => "Action received by Rails" } })
payload = { action: "continue_conversation", args: {}, surface_id: "installed-gem", version: 0, idempotency_key: "denied-fixture" }
passed = false
begin
  OpenUI::Rails::Actions::Dispatcher.from_configuration.call(payload)
  abort "generated setup unexpectedly authorized an action"
rescue OpenUI::Rails::UnauthorizedActionError
  # Explicit host policy is still required after library preparation.
end
OpenUI::Rails.configure do |config|
  config.actor_resolver = ->(_) { "package-fixture-actor" }
  config.surface_resolver = ->(id, actor:, **) {
    OpenUI::Rails::Surface.new(id: id, version: 0) if actor == "package-fixture-actor" && id == "installed-gem"
  }
  config.authorize_action = ->(invocation) { invocation.actor == "package-fixture-actor" }
end

module PackageLoopbackPortProbe
  def free?(port)
    TCPServer.open("127.0.0.1", port) { true }
  rescue Errno::EADDRINUSE
    false
  end
end
Selenium::WebDriver::PortProber.singleton_class.prepend(PackageLoopbackPortProbe)
Capybara.app = Rails.application
Capybara.server = :puma, { Silent: true }
Capybara.server_host = "127.0.0.1"
Capybara.default_max_wait_time = 5
Capybara.save_path = ENV.fetch("OPENUI_BROWSER_ARTIFACTS")
Capybara.register_driver :package_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  %w[--headless=new --window-size=1280,900 --disable-background-networking --no-sandbox --disable-dev-shm-usage].each { |value| options.add_argument(value) }
  options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"]
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end
Capybara.default_driver = :package_chrome
include Capybara::DSL

begin
  visit "/smoke"
  abort "default library did not render" unless page.has_text?("Installed gem ready")
  click_button "Confirm setup"
  abort "action did not reach Rails with CSRF enabled" unless page.has_text?("Action received by Rails")
  abort "browser reported an error" unless find("#setup-error", visible: :all).text.empty?
  save_screenshot(File.join(Capybara.save_path, "installed-gem-desktop.png"))
  page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
  page.refresh
  abort "mobile default library did not render" unless page.has_text?("Installed gem ready")
  abort "mobile page overflowed" unless page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  save_screenshot(File.join(Capybara.save_path, "installed-gem-mobile.png"))
  puts "Built gem: library tasks, doctor, real rendering, CSRF-protected action, and mobile layout passed"
  passed = true
ensure
  begin
    save_screenshot(File.join(Capybara.save_path, "installed-gem-failed.png")) unless passed
  rescue StandardError => error
    warn "Package screenshot unavailable: #{error.class}"
  ensure
    begin
      Capybara.reset_sessions!
    ensure
      Capybara.current_session.driver.quit
    end
  end
end
