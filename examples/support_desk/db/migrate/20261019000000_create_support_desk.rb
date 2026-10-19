# frozen_string_literal: true

class CreateSupportDesk < ActiveRecord::Migration[8.0] # :nodoc:
  def change
    create_table :support_desk_users do |t|
      t.string :name, null: false
      t.string :tenant_id, null: false
      t.string :role, null: false
    end
    add_index :support_desk_users, :name, unique: true
    create_table :support_desk_tickets do |t|
      t.string :tenant_id, null: false
      t.string :title, null: false
      t.string :status, null: false, default: "open"
    end
    create_table :support_desk_conversations do |t|
      t.references :user, null: false, foreign_key: { to_table: :support_desk_users }
      t.references :ticket, null: false, foreign_key: { to_table: :support_desk_tickets }
      t.string :tenant_id, null: false
      t.integer :version, null: false, default: 0
      t.text :response, null: false, default: ""
      t.integer :next_sequence, null: false, default: 0
      t.json :form_state, null: false, default: {}
      t.json :messages, null: false, default: []
    end
    create_table :support_desk_receipts do |t|
      t.references :ticket, null: false, foreign_key: { to_table: :support_desk_tickets }
      t.string :operation, null: false
    end
    # Domain-level guard survives a process restart and idempotency-store expiry.
    add_index :support_desk_receipts, [ :ticket_id, :operation ], unique: true
  end
end
