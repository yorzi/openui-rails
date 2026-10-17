source "https://rubygems.org"

# Specify your gem's dependencies in openui-rails.gemspec.
gemspec

# Pin Rails for the CI compatibility matrix, e.g. RAILS_VERSION=8.0.
rails_version = ENV["RAILS_VERSION"]
gem "rails", "~> #{rails_version}.0" if rails_version

gem "puma"

gem "sqlite3"

gem "propshaft"

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop-rails-omakase", require: false

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
