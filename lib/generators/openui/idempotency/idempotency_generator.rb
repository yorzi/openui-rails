# frozen_string_literal: true

require "rails/generators/active_record"

module OpenUI
  # Generate the opt-in shared action-claim table without changing configuration.
  class IdempotencyGenerator < ::ActiveRecord::Generators::Base
    namespace "openui:idempotency"
    source_root File.expand_path("templates", __dir__)
    desc "Create the optional OpenUI shared idempotency store migration."
    # This generator has no model-name argument.
    argument :name, type: :string, default: "openui_action_claims", hide: true

    # Write the optional, reversible host migration.
    def create_store_migration
      migration_template "create_openui_action_claims.rb", "db/migrate/create_openui_action_claims.rb"
    end
  end
end
