# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/openui/idempotency/idempotency_generator"

class IdempotencyGeneratorTest < Rails::Generators::TestCase
  tests OpenUI::IdempotencyGenerator
  destination File.expand_path("../../tmp/idempotency-generator", __dir__)
  setup :prepare_destination

  test "generates one reversible migration without enabling the store" do
    run_generator
    assert_migration "db/migrate/create_openui_action_claims.rb" do |content|
      assert_includes content, "class CreateOpenUIActionClaims"
      assert_includes content, "unique: true"
      assert_includes content, "expires_at"
    end
    assert_no_file "config/initializers/openui.rb"
    run_generator
    assert_equal 1, Dir[File.join(destination_root, "db/migrate/*create_openui_action_claims.rb")].size
  end
end
