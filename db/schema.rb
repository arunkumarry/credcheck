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

ActiveRecord::Schema[8.0].define(version: 2026_05_02_181536) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bank_offers", force: :cascade do |t|
    t.bigint "bank_id"
    t.string "merchant_name"
    t.text "offer_details"
    t.string "category"
    t.date "expiry_date"
    t.string "source_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_id"], name: "index_bank_offers_on_bank_id"
  end

  create_table "banks", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cards", force: :cascade do |t|
    t.string "name", null: false
    t.integer "status", default: 0, null: false
    t.text "description"
    t.jsonb "data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "bank_id", null: false
    t.datetime "last_scraped_at"
    t.index ["bank_id"], name: "index_cards_on_bank_id"
  end

  create_table "chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "model_id"
    t.index ["model_id"], name: "index_chats_on_model_id"
  end

  create_table "document_embeddings", force: :cascade do |t|
    t.string "document_name"
    t.text "content"
    t.json "vector"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "documents", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.string "source_url"
    t.vector "embedding"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "messages", force: :cascade do |t|
    t.string "role", null: false
    t.text "content"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "chat_id", null: false
    t.bigint "model_id"
    t.bigint "tool_call_id"
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "models", force: :cascade do |t|
    t.string "model_id", null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.string "family"
    t.datetime "model_created_at"
    t.integer "context_window"
    t.integer "max_output_tokens"
    t.date "knowledge_cutoff"
    t.jsonb "modalities", default: {}
    t.jsonb "capabilities", default: []
    t.jsonb "pricing", default: {}
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_models_on_family"
    t.index ["modalities"], name: "index_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "recommendations", force: :cascade do |t|
    t.string "category", null: false
    t.float "amount", null: false
    t.jsonb "data", default: "{}", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.integer "cached_tokens", default: 0
    t.float "cost_savings", default: 0.0
    t.bigint "user_id"
    t.index ["user_id"], name: "index_recommendations_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tool_calls", force: :cascade do |t|
    t.string "tool_call_id", null: false
    t.string "name", null: false
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "message_id", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["name"], name: "index_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id", unique: true
  end

  create_table "transactions", force: :cascade do |t|
    t.string "category", null: false
    t.float "amount", null: false
    t.bigint "user_id", null: false
    t.bigint "recommendation_id", null: false
    t.bigint "card_id"
    t.boolean "complete", default: true, null: false
    t.integer "status", default: 0, null: false
    t.float "saved_amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_transactions_on_card_id"
    t.index ["recommendation_id"], name: "index_transactions_on_recommendation_id"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "api_token"
    t.string "subscription_plan"
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "users_cards", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "card_id", null: false
    t.integer "status", default: 0, null: false
    t.jsonb "data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_users_cards_on_card_id"
    t.index ["user_id"], name: "index_users_cards_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bank_offers", "banks"
  add_foreign_key "cards", "banks"
  add_foreign_key "chats", "models"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "messages", "tool_calls"
  add_foreign_key "recommendations", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "tool_calls", "messages"
  add_foreign_key "transactions", "cards"
  add_foreign_key "transactions", "recommendations"
  add_foreign_key "transactions", "users"
  add_foreign_key "users_cards", "cards"
  add_foreign_key "users_cards", "users"
end
