# frozen_string_literal: true

class CreateOpenUIActionClaims < ActiveRecord::Migration[8.0]
  def change
    create_table :openui_action_claims do |t|
      t.string :key, null: false
      t.string :digest
      t.string :claim_token, null: false
      t.boolean :completed, null: false, default: false
      t.text :result_json
      t.datetime :expires_at, null: false, precision: 6
    end
    add_index :openui_action_claims, :key, unique: true
    add_index :openui_action_claims, :expires_at
  end
end
