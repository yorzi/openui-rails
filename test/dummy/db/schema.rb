# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_10_20_000000) do
  create_table "openui_action_claims", force: :cascade do |t|
    t.string "key", null: false
    t.string "digest"
    t.string "claim_token", null: false
    t.boolean "completed", default: false, null: false
    t.text "result_json"
    t.datetime "expires_at", null: false
    t.index ["expires_at"], name: "index_openui_action_claims_on_expires_at"
    t.index ["key"], name: "index_openui_action_claims_on_key", unique: true
  end
end
