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

ActiveRecord::Schema[8.0].define(version: 2025_10_19_203458) do
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

  create_table "audios", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.integer "duration"
    t.integer "bitrate"
    t.string "artist"
    t.string "album"
    t.string "genre"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "media", force: :cascade do |t|
    t.string "file_path", null: false
    t.integer "file_size"
    t.string "original_filename"
    t.string "content_type"
    t.string "md5_hash", null: false
    t.bigint "uploaded_by_id", null: false
    t.bigint "user_id", null: false
    t.string "medium_type", null: false
    t.string "mediable_type", null: false
    t.bigint "mediable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "upload_started_at"
    t.datetime "upload_completed_at"
    t.datetime "processing_started_at"
    t.datetime "processing_completed_at"
    t.string "upload_session_id"
    t.string "upload_batch_id"
    t.text "client_file_path"
    t.datetime "datetime_source_last_modified"
    t.datetime "datetime_intrinsic"
    t.datetime "datetime_user"
    t.datetime "datetime_inferred"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.index ["created_at"], name: "index_media_on_created_at"
    t.index ["datetime_inferred"], name: "index_media_on_datetime_inferred"
    t.index ["datetime_intrinsic"], name: "index_media_on_datetime_intrinsic"
    t.index ["datetime_source_last_modified"], name: "index_media_on_datetime_source_last_modified"
    t.index ["datetime_user"], name: "index_media_on_datetime_user"
    t.index ["file_path"], name: "index_media_on_file_path", unique: true
    t.index ["latitude"], name: "index_media_on_latitude"
    t.index ["longitude"], name: "index_media_on_longitude"
    t.index ["md5_hash"], name: "index_media_on_md5_hash", unique: true
    t.index ["mediable_type", "mediable_id"], name: "index_media_on_mediable"
    t.index ["medium_type"], name: "index_media_on_medium_type"
    t.index ["uploaded_by_id"], name: "index_media_on_uploaded_by_id"
    t.index ["user_id"], name: "index_media_on_user_id"
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
    t.json "exif_data", default: {}
    t.string "thumbnail_path"
    t.integer "thumbnail_width"
    t.integer "thumbnail_height"
    t.float "latitude"
    t.float "longitude"
    t.string "camera_make"
    t.string "camera_model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "preview_path"
    t.integer "preview_width"
    t.integer "preview_height"
    t.integer "width"
    t.integer "height"
    t.index ["height"], name: "index_photos_on_height"
    t.index ["width"], name: "index_photos_on_width"
  end

  create_table "upload_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "session_started_at"
    t.datetime "session_completed_at"
    t.string "session_id"
    t.string "batch_id"
    t.text "user_agent"
    t.integer "total_files_selected", default: 0
    t.integer "files_imported", default: 0
    t.integer "files_skipped", default: 0
    t.jsonb "files_data", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "completion_status", default: "incomplete", null: false
    t.integer "files_failed", default: 0, null: false
    t.index ["batch_id"], name: "index_upload_logs_on_batch_id", unique: true
    t.index ["completion_status"], name: "index_upload_logs_on_completion_status"
    t.index ["files_data"], name: "index_upload_logs_on_files_data", using: :gin
    t.index ["files_failed"], name: "index_upload_logs_on_files_failed"
    t.index ["user_id"], name: "index_upload_logs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "role", default: "family_member", null: false
    t.boolean "active", default: true, null: false
    t.index ["active"], name: "index_users_on_active"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["first_name", "last_name"], name: "index_users_on_first_name_and_last_name"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "albums", "photos", column: "cover_photo_id"
  add_foreign_key "albums", "users"
  add_foreign_key "albums", "users", column: "created_by_id"
  add_foreign_key "media", "users"
  add_foreign_key "media", "users", column: "uploaded_by_id"
  add_foreign_key "photo_albums", "albums"
  add_foreign_key "photo_albums", "photos"
  add_foreign_key "upload_logs", "users"
end
