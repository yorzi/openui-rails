# frozen_string_literal: true

# The gem does not own application tables; the host Rails app is authoritative
# for persisted state. This schema exists only so the dummy app can boot the
# ActiveRecord railtie during tests.
ActiveRecord::Schema[8.0].define(version: 0) do
end
