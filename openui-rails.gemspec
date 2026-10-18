# frozen_string_literal: true

require_relative "lib/openui/rails/version"

Gem::Specification.new do |spec|
  spec.name = "openui-rails"
  spec.version = OpenUI::Rails::VERSION
  spec.authors = [ "Andy Wang" ]
  spec.email = [ "wangyaodi@gmail.com" ]

  spec.summary = "Unofficial Rails integration for Thesys OpenUI Lang."
  spec.description = <<~DESC
    Render model-generated, streaming, interactive OpenUI Lang UI inside an
    existing Rails application without migrating the whole frontend to a
    React/Next.js SPA. Reuses the official, version-pinned OpenUI JavaScript
    runtime, keeps Rails authoritative for authentication, authorization and
    persistence, and ships an optional RubyLLM adapter. This is an unofficial
    integration and is not affiliated with, endorsed by, or maintained by
    Thesys.
  DESC

  spec.homepage = "https://github.com/yorzi/openui-rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/main/README.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib}/**/*", "LICENSE", "README.md", "CHANGELOG.md", "THIRD_PARTY_NOTICES.md",
      "CONFIGURATION.md", "UPGRADING.md", "SECURITY.md", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md",
      "RELEASING.md", "AUDIT.md"].select { |path| File.file?(path) }
  end
  spec.require_paths = [ "lib" ]

  spec.add_dependency "rails", ">= 8.0", "< 9.0"
end
