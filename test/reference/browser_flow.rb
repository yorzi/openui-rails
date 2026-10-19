# frozen_string_literal: true

# This driver runs against either test/dummy or a generated consumer. It imports
# no app fixtures, prompts, specs, or application files from the source checkout.
abort "Use bin/check-reference with its disposable database" unless ENV["OPENUI_REFERENCE_TEST_DATABASE"] == "1"
require File.join(ENV.fetch("OPENUI_REFERENCE_HOST"), "config/environment")
require "minitest/autorun"
require "capybara/dsl"
require "capybara/minitest"
require "selenium-webdriver"
if ENV["OPENUI_REFERENCE_ARTIFACT"]
  artifact = File.realpath(ENV.fetch("OPENUI_REFERENCE_ARTIFACT"))
  abort "consumer loaded source checkout" unless File.realpath(Gem.loaded_specs.fetch("openui-rails").full_gem_path) == artifact
  abort "consumer loaded reference from source checkout" unless File.realpath(SupportDesk::Engine.root).start_with?(artifact + "/")
end
ActionController::Base.allow_forgery_protection = true
module ReferenceLoopbackPortProbe
  def free?(port)
    TCPServer.open("127.0.0.1", port) { true }
  rescue Errno::EADDRINUSE
    false
  end
end
Selenium::WebDriver::PortProber.singleton_class.prepend(ReferenceLoopbackPortProbe)
Capybara.app = Rails.application
Capybara.server = :puma, { Silent: true }
Capybara.server_host = "127.0.0.1"
Capybara.default_max_wait_time = 8
Capybara.save_path = ENV.fetch("OPENUI_BROWSER_ARTIFACTS")
Capybara.register_driver :reference_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  %w[--headless=new --window-size=1280,1000 --disable-background-networking --no-sandbox --disable-dev-shm-usage].each { |v| options.add_argument(v) }
  options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"]
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end
Capybara.default_driver = :reference_chrome

class ReferenceWorkflowTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def setup
    SupportDesk::Receipt.delete_all
    SupportDesk::Conversation.delete_all
    SupportDesk::Ticket.delete_all
    SupportDesk::User.delete_all
    SupportDesk::Demo.seed!
  end

  def teardown
    unless passed?
      File.write(File.join(Capybara.save_path, "#{name}-console.json"), JSON.pretty_generate(page.driver.browser.logs.get(:browser).map(&:as_json)))
      File.write(File.join(Capybara.save_path, "#{name}-page.html"), page.html)
    end
    save_screenshot(File.join(Capybara.save_path, "#{name}-#{passed? ? 'passed' : 'failed'}.png"))
  ensure
    begin
      Capybara.reset_sessions!
    ensure
      Capybara.current_session.driver.quit
    end
  end

  def test_stream_query_note_reload_continue_and_authorized_mutation
    sign_in
    assert_selector "[data-controller='openui'][aria-busy='false']"
    fill_in "Private note", with: "Escalate tomorrow"
    assert_selector "#desk-status", text: "Draft saved"
    assert_equal "Escalate tomorrow", alice_conversation.reload.form_state.dig("reply", "note", "value")
    page.refresh
    assert_field "Private note", with: "Escalate tomorrow"
    assert_operator find("[data-controller='openui']")["data-openui-next-sequence"].to_i, :>, 0
    assert_equal "true", find("[data-controller='openui']")["data-openui-completed"]
    click_button "Continue conversation"
    assert_text "Conversation turns: 1"
    assert_field "Private note", with: "Escalate tomorrow"
    assert_equal "Review this ticket", alice_conversation.reload.messages.last.fetch("text")
    find_button("Close ticket").send_keys(:enter)
    assert_text "closed"
    assert_equal "closed", alice_conversation.ticket.reload.status
    assert_equal 1, SupportDesk::Receipt.where(ticket_id: alice_conversation.ticket_id).count
    assert_empty find("#desk-error", visible: :all).text
    save_screenshot(File.join(Capybara.save_path, "reference-desktop.png"))
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    page.refresh
    assert_field "Private note", with: "Escalate tomorrow"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    save_screenshot(File.join(Capybara.save_path, "reference-mobile.png"))
  end

  def test_a_lost_turbo_envelope_recovers_from_the_scoped_snapshot
    visit "/support"
    page.execute_script(<<~JS)
      window.droppedEnvelope = false
      document.addEventListener("turbo:before-stream-render", event => {
        const element = event.target.templateElement.content.querySelector("[data-openui-envelope-payload]")
        if (!element || window.droppedEnvelope) return
        if (JSON.parse(element.dataset.openuiEnvelopePayload).sequence === 1) {
          window.droppedEnvelope = true
          event.preventDefault()
        }
      })
    JS
    click_button "Sign in as Alice"
    assert_selector "[data-controller='support-desk'][data-recovered='true']"
    assert_text "North delivery question"
    assert_selector "[data-controller='openui'][aria-busy='false']"
    assert_equal true, page.evaluate_script("window.droppedEnvelope")
    assert_empty find("#desk-error", visible: :all).text
  end

  def test_a_reload_fences_late_frames_from_a_completed_response
    sign_in
    page.refresh
    assert_text "North delivery question"
    message = find("[data-controller='openui']")["data-openui-message-id"]
    page.execute_script(<<~JS, message)
      document.dispatchEvent(new CustomEvent("openui:envelope", {detail: {
        type: "openui.delta", message_id: arguments[0], sequence: 0, delta: "INVALID LATE FRAME"
      }}))
    JS
    assert_text "North delivery question"
    assert_empty find("#desk-error", visible: :all).text
    assert_equal "true", find("[data-controller='openui']")["data-openui-completed"]
  end

  def test_wrong_tenant_cannot_read_stream_snapshot_save_or_act
    sign_in
    bob = SupportDesk::User.find_by!(name: "Bob")
    other = SupportDesk::Conversation.find_by!(user_id: bob.id)
    [ [ "GET", "" ], [ "GET", "/snapshot" ], [ "POST", "/stream" ], [ "PATCH", "/state" ] ].each do |method, suffix|
      response = request(method, "/support/conversations/#{other.id}#{suffix}", { state: {}, version: 0 })
      assert_equal 404, response["status"]
      refute_includes response["text"], "South delivery question"
    end
    response = request("POST", "/openui-rails/actions", action_payload.merge(surface_id: other.id.to_s))
    assert_equal 403, response["status"]
    assert_equal "open", other.ticket.reload.status
    assert_equal 0, SupportDesk::Receipt.count
  end

  def test_expired_identity_is_denied_on_the_existing_surface
    sign_in
    # Log out through the real session endpoint, leaving the old surface in view.
    # Use the new anonymous page's token to isolate authorization from CSRF failure.
    page.driver.browser.execute_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      fetch("/support/session", {method: "DELETE", headers: {"X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content}})
        .then(r => r.text()).then(html => {
          const page = new DOMParser().parseFromString(html, "text/html")
          document.querySelector("meta[name='csrf-token']").content = page.querySelector("meta[name='csrf-token']").content
          done(true)
        }).catch(error => done(String(error)))
    JS
    response = request("GET", "/support/conversations/#{alice_conversation.id}/snapshot")
    assert_equal 401, response["status"]
    click_button "Close ticket"
    assert_selector "#desk-error", text: "Action not permitted. Sign in again."
    assert_equal "open", alice_conversation.ticket.reload.status
    assert_equal 0, SupportDesk::Receipt.count
  end

  def test_duplicate_and_stale_submissions_have_one_persisted_effect
    sign_in
    body = action_payload
    results = page.driver.browser.execute_async_script(<<~JS, body)
      const done = arguments[arguments.length - 1], body = arguments[0]
      const send = () => fetch("/openui-rails/actions", {method: "POST", headers: {
        "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      }, body: JSON.stringify(body)}).then(async r => ({status: r.status, body: await r.json()}))
      Promise.all([send(), send()]).then(done).catch(error => done({error: String(error)}))
    JS
    assert_equal [ 200, 409 ], results.map { |r| r["status"] }.sort
    assert_equal 1, SupportDesk::Receipt.count
    assert_equal "closed", alice_conversation.ticket.reload.status
    OpenUI::Rails.configuration.idempotency_store = OpenUI::Rails::Actions::Idempotency::MemoryStore.new
    stale = request("POST", "/openui-rails/actions", body.merge(idempotency_key: "new-key"))
    assert_equal 409, stale["status"]
    assert_equal "stale_surface", JSON.parse(stale["text"]).dig("error", "code")
    assert_equal 1, SupportDesk::Receipt.count
  end

  def test_reader_can_query_but_cannot_modify_a_ticket
    sign_in("Reader")
    click_button "Close ticket"
    assert_selector "#desk-error", text: "Action not permitted"
    assert_equal 0, SupportDesk::Receipt.count
  end

  def test_state_writes_are_bounded_and_csrf_protected
    sign_in
    path = "/support/conversations/#{alice_conversation.id}/state"
    [ { version: 0, state: { secret: "no" } }, { version: 0, state: [] }, { version: 0, state: nil },
      { version: "invalid", state: {} }, { version: 0, state: { reply: { note: { value: "x" * 2001 } } } } ].each do |body|
      assert_equal 422, request("PATCH", path, body)["status"]
    end
    assert_equal 409, request("PATCH", path, { version: 9, state: {} })["status"]
    response = request("POST", "/openui-rails/actions", action_payload, csrf: false)
    assert_equal 422, response["status"]
    assert_equal "csrf_failed", JSON.parse(response["text"]).dig("error", "code")
    assert_equal "open", alice_conversation.ticket.reload.status
  end

  private

  def sign_in(name = "Alice")
    visit "/support"
    click_button "Sign in as #{name}"
    assert_text "North delivery question"
    assert_button "Close ticket"
  end

  def alice_conversation
    SupportDesk::Conversation.find_by!(user_id: SupportDesk::User.find_by!(name: "Alice").id)
  end

  def action_payload
    { action: "close_ticket", args: {}, surface_id: alice_conversation.id.to_s,
      version: 0, idempotency_key: SecureRandom.uuid }
  end

  def request(method, url, body = nil, csrf: true)
    page.driver.browser.execute_async_script(<<~JS, method, url, body, csrf)
      const done = arguments[arguments.length - 1]
      const headers = {"Content-Type": "application/json", Accept: "application/json"}
      if (arguments[3]) headers["X-CSRF-Token"] = document.querySelector("meta[name='csrf-token']").content
      fetch(arguments[1], {method: arguments[0], headers, body: arguments[0] === "GET" ? undefined : JSON.stringify(arguments[2])})
        .then(async r => done({status: r.status, text: await r.text()})).catch(error => done({error: String(error)}))
    JS
  end
end
