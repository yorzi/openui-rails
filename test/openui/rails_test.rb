# frozen_string_literal: true

require "test_helper"

class OpenUI::RailsTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert OpenUI::Rails::VERSION
  end

  test "the engine isolates the OpenUI::Rails namespace" do
    assert OpenUI::Rails::Engine.isolated?
    assert OpenUI::Rails::Engine < ::Rails::Engine
  end
end
