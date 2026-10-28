# frozen_string_literal: true

require_relative "config/environment"
require "capybara/dsl"
require "capybara/minitest"
require "selenium-webdriver"
require "minitest/assertions"
abort "Wrong artifact loaded" unless File.realpath(Gem.loaded_specs.fetch("openui-rails").full_gem_path) == File.realpath(ENV.fetch("QUALIFICATION_ARTIFACT"))
abort "Reference host leaked into independent consumer" if defined?(SupportDesk)
unless ActiveRecord::Base.connection.table_exists?(:host_records)
  ActiveRecord::Schema.define do
    create_table(:host_records) do |table|
      table.integer :actor_id, null: false
      table.text :response, null: false
      table.string :draft, null: false
      table.string :library_version, null: false
      table.integer :effects, default: 0, null: false
    end
  end
  source = ENV["QUALIFICATION_SOURCE"] ? File.read(ENV.fetch("QUALIFICATION_SOURCE")) :
    'root = Card([TextContent("Release readiness"), Buttons([Button("Confirm setup", @ToAssistant("confirm"))])])'
  HostRecord.create!(id: 1, actor_id: 1, response: source, draft: "Keep this draft", library_version: OpenUI::Rails.configuration.library_fingerprint)
end
module QualificationLoopbackPort
  def free?(port)
    TCPServer.open("127.0.0.1", port) { true }
  rescue Errno::EADDRINUSE
    false
  end
end
Selenium::WebDriver::PortProber.singleton_class.prepend(QualificationLoopbackPort)
Capybara.app = Rails.application
Capybara.server = :puma, { Silent: true }
Capybara.server_host = "127.0.0.1"
Capybara.default_max_wait_time = 10
Capybara.register_driver :qualification do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  %w[--headless=new --window-size=1280,900 --disable-background-networking --no-sandbox --disable-dev-shm-usage].each { |flag| options.add_argument(flag) }
  options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"]
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end
Capybara.default_driver = :qualification

class HostQualification
  include Capybara::DSL
  include Capybara::Minitest::Assertions
  include Minitest::Assertions
  attr_accessor :assertions

  def run
    self.assertions = 0
    stage = ENV.fetch("QUALIFICATION_STAGE").to_i
    visit "/"
    assert_text "Release readiness"
    assert_text "Keep this draft"
    assert_text "Effects: #{stage}"
    assert_equal stage, HostRecord.find(1).effects
    find_button("Confirm setup").send_keys(:enter)
    assert_text "Effects: #{stage + 1}"
    assert_equal stage + 1, HostRecord.find(1).effects
    page.refresh
    assert_text "Effects: #{stage + 1}"
    assert_text "Release readiness"
    assert_empty find("#error", visible: :all).text
    save_screenshot(File.join(ENV.fetch("OPENUI_BROWSER_ARTIFACTS"), "stage-#{stage}-interface.png"))
    if ENV["QUALIFICATION_CANDIDATE"] == "true"
      visit "/?mismatch=1"
      assert_selector "[role='alert']", text: "different library"
      assert_no_selector "[data-controller='openui']"
      assert_equal stage + 1, HostRecord.find(1).effects
    end
    puts "#{OpenUI::Rails::VERSION}: #{assertions} public-host assertions passed (stage #{stage}, effects #{stage + 1})"
  ensure
    save_screenshot(File.join(ENV.fetch("OPENUI_BROWSER_ARTIFACTS"), "stage-#{stage}.png")) if page.driver.browser
    Capybara.reset_sessions!
    Capybara.current_session.driver.quit
  end
end
HostQualification.new.run
