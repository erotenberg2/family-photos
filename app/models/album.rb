class Album < ApplicationRecord
  belongs_to :cover_photo, class_name: 'Photo', optional: true
  belongs_to :user
  belongs_to :created_by, class_name: 'User'
  
  has_many :photo_albums, dependent: :destroy
  has_many :photos, through: :photo_albums, source: :photo
  
  # Validations
  validates :title, presence: true, length: { minimum: 1, maximum: 255 }
  validates :private, inclusion: { in: [true, false] }
  
  # Scopes
  scope :public_albums, -> { where(private: false) }
  scope :private_albums, -> { where(private: true) }
  scope :by_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_title, -> { order(:title) }
  
  # Instance methods
  def add_photo(photo, position = nil)
    position ||= next_position
    photo_albums.create!(photo: photo, position: position)
  end
  
  def remove_photo(photo)
    photo_albums.find_by(photo: photo)&.destroy
    reorder_photos
  end
  
  def reorder_photos
    photo_albums.order(:position).each_with_index do |pa, index|
      pa.update!(position: index + 1)
    end
  end
  
  def ordered_photos
    photos.joins(:photo_albums)
          .where(photo_albums: { album: self })
          .order('photo_albums.position ASC')
  end
  
  def photo_count
    photos.count
  end
  
  def set_cover_photo(photo)
    if photos.include?(photo)
      update!(cover_photo: photo)
    else
      add_photo(photo)
      update!(cover_photo: photo)
    end
  end
  
  def auto_set_cover_photo
    return if cover_photo.present?
    
    first_photo = ordered_photos.first
    update!(cover_photo: first_photo) if first_photo
  end
  
  def accessible_by?(current_user)
    return true unless private?
    return true if user == current_user
    return true if created_by == current_user
    
    false
  end
  
  def total_file_size
    photos.sum(:file_size)
  end
  
  def date_range
    photo_dates = photos.joins(:medium).where.not(media: { datetime_user: nil }).pluck('media.datetime_user')
    photo_dates += photos.joins(:medium).where(media: { datetime_user: nil }).where.not(media: { datetime_intrinsic: nil }).pluck('media.datetime_intrinsic')
    photo_dates += photos.joins(:medium).where(media: { datetime_user: nil, datetime_intrinsic: nil }).where.not(media: { datetime_inferred: nil }).pluck('media.datetime_inferred')
    return nil if photo_dates.empty?
    
    {
      start_date: photo_dates.min,
      end_date: photo_dates.max
    }
  end
  
  private
  
  def next_position
    max_position = photo_albums.maximum(:position) || 0
    max_position + 1
  end
end
