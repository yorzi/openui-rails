source "https://rubygems.org"

# Specify your gem's dependencies in openui-rails.gemspec.
gemspec

# Pin Rails for the CI compatibility matrix, e.g. RAILS_VERSION=8.0.
rails_version = ENV["RAILS_VERSION"]
gem "rails", "~> #{rails_version}.0" if rails_version

# Rails 8.0.x passes `quirks_mode:` to JSON.generate (in ActiveSupport and in
# the integration-test helper), a keyword json >= 3 removed. Rails 8.1 dropped
# it. Constrain json for the 8.0 matrix; see the README compatibility note.
gem "json", "< 3" if rails_version&.start_with?("8.0")

gem "puma"

gem "sqlite3"

gem "propshaft"

group :development, :test do
  # The dummy app mirrors a real Rails 8 host: importmap + Stimulus, no build.
  gem "importmap-rails"
  gem "stimulus-rails"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  # Compatibility probes only; neither is a runtime dependency of the gem.
  gem "ruby_llm", "2.1.1", require: false
  gem "webmock", "~> 3.0", require: false
end

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop-rails-omakase", require: false

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
