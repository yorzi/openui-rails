# frozen_string_literal: true

require "application_system_test_case"

# Accessibility basics for the mount element this Gem renders: a streaming
# region is marked busy until it settles, a labelled surface is exposed as a
# named region, and the rendered UI is not hidden from assistive technology.
class OpenUIAccessibilitySystemTest < ApplicationSystemTestCase
  test "a settled surface is not marked busy" do
    visit "/demo"

    assert_selector ".openui-surface[data-openui-surface-id='surface-1'][aria-busy='false']"
  end

  test "a streaming surface is busy until it completes" do
    visit "/demo"

    assert_selector ".openui-surface[data-openui-surface-id='surface-2'][aria-busy='true']"

    dispatch({ "message_id" => "surface-2", "sequence" => 1, "type" => "openui.completed", "streaming" => false })

    assert_selector ".openui-surface[data-openui-surface-id='surface-2'][aria-busy='false']"
  end

  test "a stream error clears the busy state" do
    visit "/demo"

    assert_selector ".openui-surface[data-openui-surface-id='surface-2'][aria-busy='true']"

    dispatch({ "message_id" => "surface-2", "sequence" => 1, "type" => "openui.error",
               "code" => "provider_rejected", "message" => "nope" })

    assert_selector ".openui-surface[data-openui-surface-id='surface-2'][aria-busy='false']"
  end

  test "a labelled surface is exposed as a named region" do
    visit "/demo"

    assert_selector "div.openui-surface[role='region'][aria-label='Order details']"
  end

  test "the rendered region is not hidden from assistive technology" do
    visit "/demo"

    assert_selector "[data-openui-rendered='true']"
    assert_no_selector "[aria-hidden='true'] [data-openui-rendered='true']"
    assert_no_selector ".openui-surface[aria-hidden='true']"
  end
end
