# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "open3"

class ReleaseCheckTest < ActiveSupport::TestCase
  test "candidate metadata cannot pass the publication gate" do
    with_metadata(released: false, notes: "## [Unreleased]\n\n### Added\n\n- Candidate feature.\n") do |root|
      assert check(root, "--candidate")
      refute check(root, "v#{OpenUI::Rails::VERSION}")
    end
  end

  test "publication requires matching version released status and dated notes" do
    version = OpenUI::Rails::VERSION
    with_metadata(released: true, notes: "## [#{version}] - 2026-10-19\n\n- Delivered feature.\n") do |root|
      assert check(root, "v#{version}")
      refute check(root, "--candidate")
      refute check(root, "v99.0.0")
      File.write(File.join(root, "docs/_config.yml"), "version: 99.0.0\nreleased: true\n")
      refute check(root, "v#{version}")
    end
  end

  test "an empty unreleased section cannot pass candidate preparation" do
    with_metadata(released: false, notes: "## [Unreleased]\n\n## [0.1.0] - 2026-10-18\n\n- Old feature.\n") do |root|
      refute check(root, "--candidate")
    end
  end

  private

  def check(root, *arguments)
    _out, _err, status = Open3.capture3({ "RELEASE_TAG" => nil }, RbConfig.ruby, File.join(root, "bin/check-release"), *arguments)
    status.success?
  end

  def with_metadata(released:, notes:)
    Dir.mktmpdir("openui-release-check") do |root|
      FileUtils.mkdir_p([ "bin", "lib/openui/rails", "docs" ].map { |path| File.join(root, path) })
      FileUtils.cp(OpenUI::Rails::Engine.root.join("bin/check-release"), File.join(root, "bin/check-release"))
      FileUtils.cp(OpenUI::Rails::Engine.root.join("lib/openui/rails/version.rb"), File.join(root, "lib/openui/rails/version.rb"))
      File.write(File.join(root, "CHANGELOG.md"), notes)
      File.write(File.join(root, "docs/_config.yml"), "version: #{OpenUI::Rails::VERSION}\nreleased: #{released}\n")
      yield root
    end
  end
end
