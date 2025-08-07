class PhotoAlbum < ApplicationRecord
  belongs_to :photo
  belongs_to :album
  
  # Validations
  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :photo_id, uniqueness: { scope: :album_id, message: "Photo already exists in this album" }
  
  # Scopes
  scope :ordered, -> { order(:position) }
  
  # Callbacks
  before_validation :set_position, if: :new_record?
  after_destroy :reorder_remaining_photos
  
  private
  
  def set_position
    return if position.present?
    
    max_position = album.photo_albums.maximum(:position) || 0
    self.position = max_position + 1
  end
  
  def reorder_remaining_photos
    album.reorder_photos
  end
end
