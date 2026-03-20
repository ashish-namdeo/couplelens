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

ActiveRecord::Schema[7.0].define(version: 2026_03_19_103822) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "bookings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "therapist_profile_id", null: false
    t.string "session_type"
    t.datetime "scheduled_at"
    t.integer "duration"
    t.integer "status"
    t.text "notes"
    t.decimal "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["therapist_profile_id"], name: "index_bookings_on_therapist_profile_id"
    t.index ["user_id"], name: "index_bookings_on_user_id"
  end

  create_table "compatibility_assessments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "partner_name"
    t.float "financial_score"
    t.float "lifestyle_score"
    t.float "parenting_score"
    t.float "overall_score"
    t.text "strengths"
    t.text "risk_areas"
    t.text "full_report"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_compatibility_assessments_on_user_id"
  end

  create_table "conflict_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "partner_name"
    t.integer "status"
    t.string "topic"
    t.text "user_perspective"
    t.text "partner_perspective"
    t.text "ai_analysis"
    t.text "ai_summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_conflict_sessions_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.string "persona"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "language"
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "category"
    t.decimal "amount"
    t.string "description"
    t.date "expense_date"
    t.boolean "shared"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_expenses_on_user_id"
  end

  create_table "financial_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "monthly_income"
    t.decimal "savings_goal"
    t.string "spending_style"
    t.string "financial_personality"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_financial_profiles_on_user_id"
  end

  create_table "health_metrics", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "metric_type"
    t.float "score"
    t.text "notes"
    t.datetime "recorded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_health_metrics_on_user_id"
  end

  create_table "lessons", force: :cascade do |t|
    t.bigint "program_id", null: false
    t.string "title"
    t.text "content"
    t.integer "position"
    t.string "lesson_type"
    t.string "video_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["program_id"], name: "index_lessons_on_program_id"
  end

  create_table "memories", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.text "description"
    t.date "memory_date"
    t.string "memory_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_memories_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "role"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  create_table "programs", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "category"
    t.string "difficulty"
    t.integer "duration_weeks"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "therapist_applications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "full_name"
    t.string "email"
    t.string "specialization"
    t.text "bio"
    t.text "certifications"
    t.integer "years_experience"
    t.decimal "hourly_rate"
    t.integer "status"
    t.text "admin_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_therapist_applications_on_user_id"
  end

  create_table "therapist_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "specialization"
    t.text "bio"
    t.decimal "hourly_rate"
    t.string "languages"
    t.text "certifications"
    t.integer "years_experience"
    t.integer "status"
    t.float "rating"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_therapist_profiles_on_user_id"
  end

  create_table "user_programs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "program_id", null: false
    t.integer "current_lesson"
    t.integer "status"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["program_id"], name: "index_user_programs_on_program_id"
    t.index ["user_id"], name: "index_user_programs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "first_name"
    t.string "last_name"
    t.integer "role"
    t.integer "partner_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workshop_registrations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "workshop_id", null: false
    t.integer "status"
    t.decimal "amount_paid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_workshop_registrations_on_user_id"
    t.index ["workshop_id"], name: "index_workshop_registrations_on_workshop_id"
  end

  create_table "workshops", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "instructor"
    t.string "location"
    t.datetime "workshop_date"
    t.decimal "price"
    t.integer "capacity"
    t.integer "spots_taken"
    t.integer "status"
    t.string "workshop_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bookings", "therapist_profiles"
  add_foreign_key "bookings", "users"
  add_foreign_key "compatibility_assessments", "users"
  add_foreign_key "conflict_sessions", "users"
  add_foreign_key "conversations", "users"
  add_foreign_key "expenses", "users"
  add_foreign_key "financial_profiles", "users"
  add_foreign_key "health_metrics", "users"
  add_foreign_key "lessons", "programs"
  add_foreign_key "memories", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "therapist_applications", "users"
  add_foreign_key "therapist_profiles", "users"
  add_foreign_key "user_programs", "programs"
  add_foreign_key "user_programs", "users"
  add_foreign_key "workshop_registrations", "users"
  add_foreign_key "workshop_registrations", "workshops"
end
