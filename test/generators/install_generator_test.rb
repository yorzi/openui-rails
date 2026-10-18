# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/openui/install/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests OpenUI::InstallGenerator

  destination File.expand_path("../../tmp/generators", __dir__)

  setup :prepare_destination

  test "creates the initializer and the library directory" do
    run_generator

    assert_file "config/initializers/openui.rb" do |content|
      assert_match(/OpenUI::Rails.configure/, content)
      assert_match(/library_spec_path/, content)
    end
    assert_file "config/openui/README.md" do |content|
      assert_includes content, "bin/rails openui:library:prepare"
      assert_includes content, "bin/rails openui:doctor"
      assert_operator content.index("openui:library:prepare"), :<, content.index("@openuidev/cli")
      assert_match(/@openuidev\/cli@0\.6\.0/, content)
      assert_match(/DO_NOT_TRACK/, content)
    end
  end

  test "mounts the engine when a routes file exists" do
    FileUtils.mkdir_p(File.join(destination_root, "config"))
    File.write(File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")

    run_generator

    assert_file "config/routes.rb" do |content|
      assert_match(%r{mount OpenUI::Rails::Engine => "/openui-rails"}, content)
    end
  end

  test "does not duplicate the mount" do
    FileUtils.mkdir_p(File.join(destination_root, "config"))
    File.write(
      File.join(destination_root, "config/routes.rb"),
      %(Rails.application.routes.draw do\n  mount OpenUI::Rails::Engine => "/openui-rails"\nend\n)
    )

    run_generator

    assert_file "config/routes.rb" do |content|
      assert_equal 1, content.scan("mount OpenUI::Rails::Engine").size
    end
  end

  test "does not fail without a routes file" do
    run_generator

    assert_no_file "config/routes.rb"
  end
end
