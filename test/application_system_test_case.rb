# frozen_string_literal: true

require "test_helper"
require "selenium-webdriver"

# Selenium's port availability probe otherwise briefly binds all interfaces.
module OpenUILoopbackPortProbe
  def free?(port)
    TCPServer.open("127.0.0.1", port) { true }
  rescue Errno::EADDRINUSE
    false
  end
end
Selenium::WebDriver::PortProber.singleton_class.prepend(OpenUILoopbackPortProbe)
Capybara.server_host = "127.0.0.1"
Capybara.save_path = ENV["OPENUI_BROWSER_ARTIFACTS"] if ENV["OPENUI_BROWSER_ARTIFACTS"]

# Browser end-to-end tests run against the dummy app with a real headless
# Chrome and a deterministic stub of the OpenUI runtime (see
# test/dummy/public/openui). They exercise the openui-rails Stimulus
# controller, which is the part this Gem owns.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    # Required when Chrome runs as root in a containerised CI runner.
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-background-networking")
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"]
  end

  setup do
    ActionController::Base.allow_forgery_protection = true
  end

  def after_teardown
    if ENV["OPENUI_BROWSER_ARTIFACTS"]
      label = passed? ? "passed" : "failed"
      save_screenshot(File.join(Capybara.save_path, "#{self.class.name}-#{name.gsub(/[^a-zA-Z0-9_-]/, '_')}-#{label}.png"))
    end
  rescue StandardError => error
    warn "Browser screenshot unavailable: #{error.class}"
  ensure
    begin
      super
    ensure
      Capybara.current_session.driver.quit
    end
  end

  private

  # Record the openui:* events the controller emits on the body element, so a
  # test can wait for them with Capybara's normal retrying finders instead of
  # polling.
  def install_recorders
    page.execute_script(<<~JS)
      document.addEventListener("openui:action", (event) => {
        document.body.dataset.openuiLastAction = JSON.stringify(event.detail)
      })
      document.addEventListener("openui:error", (event) => {
        document.body.dataset.openuiLastError = JSON.stringify(event.detail)
      })
      document.addEventListener("openui:snapshot-required", (event) => {
        document.body.dataset.openuiLastSnapshot = JSON.stringify(event.detail)
      })
    JS
  end

  def dispatch(payload)
    page.execute_script(
      "document.dispatchEvent(new CustomEvent('openui:envelope', { bubbles: true, detail: arguments[0] }))",
      payload
    )
  end

  def delta(surface_id, sequence, text, streaming: true)
    {
      "message_id" => surface_id,
      "sequence" => sequence,
      "type" => "openui.delta",
      "delta" => text,
      "streaming" => streaming
    }
  end

  def within_surface(surface_id, &block)
    within ".openui-surface[data-openui-surface-id='#{surface_id}']", &block
  end

  def source_of(surface_id)
    find(".openui-surface[data-openui-surface-id='#{surface_id}'] [data-openui-source]").text
  end

  def read_json(selector, attribute)
    JSON.parse(find(selector)[attribute])
  end

  def eventually(timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      value = yield
      return value if value

      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        flunk "condition not met within #{timeout}s"
      end

      sleep 0.05
    end
  end
end
