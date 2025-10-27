class AddCaseInsensitiveTitleIndexToEvents < ActiveRecord::Migration[8.0]
  def change
    # Add a case-insensitive unique index on title
    # Using a function index for PostgreSQL to enforce case-insensitive uniqueness
    add_index :events, "lower(title)", unique: true
  end
end
