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

ActiveRecord::Schema[7.2].define(version: 2026_06_04_001913) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "assessment_responses", force: :cascade do |t|
    t.bigint "assessment_id", null: false
    t.bigint "capability_id", null: false
    t.integer "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assessment_id", "capability_id"], name: "index_assessment_responses_on_assessment_id_and_capability_id", unique: true
    t.index ["assessment_id"], name: "index_assessment_responses_on_assessment_id"
    t.index ["capability_id"], name: "index_assessment_responses_on_capability_id"
  end

  create_table "assessments", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "framework_id", null: false
    t.boolean "latest"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["framework_id"], name: "index_assessments_on_framework_id"
    t.index ["product_id"], name: "index_assessments_on_product_id"
  end

  create_table "capabilities", force: :cascade do |t|
    t.bigint "dimension_id", null: false
    t.string "name"
    t.string "slug"
    t.integer "position"
    t.integer "min_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dimension_id", "slug"], name: "index_capabilities_on_dimension_id_and_slug", unique: true
    t.index ["dimension_id"], name: "index_capabilities_on_dimension_id"
  end

  create_table "capability_levels", force: :cascade do |t|
    t.bigint "capability_id", null: false
    t.integer "value"
    t.text "description"
    t.text "formatted_description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["capability_id", "value"], name: "index_capability_levels_on_capability_id_and_value", unique: true
    t.index ["capability_id"], name: "index_capability_levels_on_capability_id"
  end

  create_table "dimensions", force: :cascade do |t|
    t.bigint "framework_id", null: false
    t.string "name"
    t.string "slug"
    t.integer "position"
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["framework_id", "slug"], name: "index_dimensions_on_framework_id_and_slug", unique: true
    t.index ["framework_id"], name: "index_dimensions_on_framework_id"
  end

  create_table "frameworks", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.text "description"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_frameworks_on_slug", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.string "product_type"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "is_assessed"
    t.boolean "is_active", default: true
    t.boolean "is_assessable", default: true
  end

  create_table "scores", force: :cascade do |t|
    t.integer "a1"
    t.integer "a2"
    t.integer "a3"
    t.integer "a4"
    t.integer "a5"
    t.integer "a6"
    t.integer "a7"
    t.integer "a8"
    t.integer "a9"
    t.integer "a10"
    t.integer "a11"
    t.integer "a12"
    t.integer "b1"
    t.integer "b2"
    t.integer "b3"
    t.integer "b4"
    t.integer "b5"
    t.integer "b6"
    t.integer "b7"
    t.integer "b8"
    t.integer "c1"
    t.integer "c2"
    t.integer "c3"
    t.integer "c4"
    t.integer "c5"
    t.integer "c6"
    t.integer "c7"
    t.integer "c8"
    t.integer "c9"
    t.integer "c10"
    t.integer "d1"
    t.integer "d2"
    t.integer "d3"
    t.integer "d4"
    t.integer "d5"
    t.integer "d6"
    t.integer "d7"
    t.integer "d8"
    t.integer "e1"
    t.integer "e2"
    t.integer "e3"
    t.integer "e4"
    t.float "a"
    t.float "b"
    t.float "c"
    t.float "d"
    t.float "e"
    t.float "total"
    t.integer "product_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "latest"
    t.text "comment"
  end

  create_table "tags", force: :cascade do |t|
    t.string "key"
    t.string "value"
    t.integer "product_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  add_foreign_key "assessment_responses", "assessments"
  add_foreign_key "assessment_responses", "capabilities"
  add_foreign_key "assessments", "frameworks"
  add_foreign_key "assessments", "products"
  add_foreign_key "capabilities", "dimensions"
  add_foreign_key "capability_levels", "capabilities"
  add_foreign_key "dimensions", "frameworks"
end
