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

ActiveRecord::Schema[8.0].define(version: 2025_08_07_011733) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

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

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "albums", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.bigint "cover_photo_id"
    t.bigint "user_id", null: false
    t.boolean "private", default: false, null: false
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cover_photo_id"], name: "index_albums_on_cover_photo_id"
    t.index ["created_by_id"], name: "index_albums_on_created_by_id"
    t.index ["private"], name: "index_albums_on_private"
    t.index ["title"], name: "index_albums_on_title"
    t.index ["user_id"], name: "index_albums_on_user_id"
  end

  create_table "photo_albums", force: :cascade do |t|
    t.bigint "photo_id", null: false
    t.bigint "album_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["album_id", "position"], name: "index_photo_albums_on_album_id_and_position"
    t.index ["album_id"], name: "index_photo_albums_on_album_id"
    t.index ["photo_id", "album_id"], name: "index_photo_albums_on_photo_id_and_album_id", unique: true
    t.index ["photo_id"], name: "index_photo_albums_on_photo_id"
  end

  create_table "photos", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "file_path", null: false
    t.integer "file_size"
    t.integer "width"
    t.integer "height"
    t.datetime "taken_at"
    t.json "exif_data", default: {}
    t.string "thumbnail_path"
    t.integer "thumbnail_width"
    t.integer "thumbnail_height"
    t.bigint "uploaded_by_id", null: false
    t.bigint "user_id", null: false
    t.string "original_filename"
    t.string "content_type"
    t.string "md5_hash"
    t.float "latitude"
    t.float "longitude"
    t.string "camera_make"
    t.string "camera_model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_photos_on_created_at"
    t.index ["latitude", "longitude"], name: "index_photos_on_latitude_and_longitude"
    t.index ["md5_hash"], name: "index_photos_on_md5_hash", unique: true
    t.index ["taken_at"], name: "index_photos_on_taken_at"
    t.index ["uploaded_by_id"], name: "index_photos_on_uploaded_by_id"
    t.index ["user_id"], name: "index_photos_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "albums", "photos", column: "cover_photo_id"
  add_foreign_key "albums", "users"
  add_foreign_key "albums", "users", column: "created_by_id"
  add_foreign_key "photo_albums", "albums"
  add_foreign_key "photo_albums", "photos"
  add_foreign_key "photos", "users"
  add_foreign_key "photos", "users", column: "uploaded_by_id"
end
