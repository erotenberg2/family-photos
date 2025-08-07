class Photo < ApplicationRecord
  belongs_to :uploaded_by, class_name: 'User'
  belongs_to :user
  
  has_many :photo_albums, dependent: :destroy
  has_many :albums, through: :photo_albums
  has_one :cover_album, class_name: 'Album', foreign_key: 'cover_photo_id'

  # Validations
  validates :file_path, presence: true, uniqueness: true
  validates :md5_hash, presence: true, uniqueness: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }
  validates :width, :height, presence: true, numericality: { greater_than: 0 }
  validates :original_filename, presence: true
  validates :content_type, presence: true, inclusion: { 
    in: %w[image/jpeg image/jpg image/png image/gif image/bmp image/tiff],
    message: 'must be a valid image format'
  }

  def self.ransackable_attributes(auth_object = nil)
    ["camera_make", "camera_model", "content_type", "created_at", "description", "exif_data", "file_path", "file_size", "height", "id", "latitude", "longitude", "md5_hash", "original_filename", "taken_at", "thumbnail_height", "thumbnail_path", "thumbnail_width", "title", "updated_at", "uploaded_by_id", "user_id", "width"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["albums", "uploaded_by", "user"]
  end

  # Scopes
  scope :by_date, -> { order(:taken_at, :created_at) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_location, -> { where.not(latitude: nil, longitude: nil) }
  scope :by_camera, ->(make, model = nil) { 
    query = where(camera_make: make)
    query = query.where(camera_model: model) if model
    query
  }

  # Callbacks
  before_save :extract_metadata_from_exif
  after_create :generate_thumbnail

  # Class methods
  def self.duplicate_by_hash(hash)
    find_by(md5_hash: hash)
  end

  def self.total_storage_size
    sum(:file_size)
  end

  # Instance methods
  def extract_exif_data(file_path)
    require 'exifr/jpeg'
    require 'exifr/tiff'
    
    return {} unless File.exist?(file_path)
    
    begin
      case content_type
      when 'image/jpeg', 'image/jpg'
        exif = EXIFR::JPEG.new(file_path)
      when 'image/tiff'
        exif = EXIFR::TIFF.new(file_path)
      else
        return {}
      end
      
      return {} unless exif
      
      # Extract key EXIF data
      {
        camera_make: exif.make,
        camera_model: exif.model,
        date_time_original: exif.date_time_original,
        gps_latitude: exif.gps_latitude,
        gps_longitude: exif.gps_longitude,
        orientation: exif.orientation,
        f_number: exif.f_number,
        exposure_time: exif.exposure_time,
        iso_speed_ratings: exif.iso_speed_ratings,
        focal_length: exif.focal_length,
        flash: exif.flash,
        white_balance: exif.white_balance,
        raw_exif: exif.to_hash
      }.compact
    rescue => e
      Rails.logger.error "Failed to extract EXIF from #{file_path}: #{e.message}"
      {}
    end
  end

  def calculate_thumbnail_size
    # Implement your custom rules here
    # This is a placeholder - you can customize based on your requirements
    
    max_dimension = if width > height
      # Landscape
      { width: 400, height: (400.0 * height / width).round }
    else
      # Portrait or square
      { width: (400.0 * width / height).round, height: 400 }
    end
    
    # Ensure minimum size
    max_dimension[:width] = [max_dimension[:width], 100].max
    max_dimension[:height] = [max_dimension[:height], 100].max
    
    max_dimension
  end

  def generate_thumbnail_path
    return nil unless file_path
    
    dir = File.dirname(file_path)
    ext = File.extname(file_path)
    base = File.basename(file_path, ext)
    
    File.join(dir, "thumbs", "#{base}_thumb#{ext}")
  end

  def has_location?
    latitude.present? && longitude.present?
  end

  def location_coordinates
    return nil unless has_location?
    [latitude, longitude]
  end

  def file_size_human
    return '0 B' if file_size.nil? || file_size.zero?
    
    units = %w[B KB MB GB TB]
    size = file_size.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    "#{size.round(1)} #{units[unit_index]}"
  end

  def taken_date
    taken_at || created_at
  end

  private

  def extract_metadata_from_exif
    return unless file_path_changed? && file_path.present?
    
    exif_info = extract_exif_data(file_path)
    self.exif_data = exif_info
    
    # Set individual fields from EXIF
    self.camera_make = exif_info[:camera_make] if exif_info[:camera_make]
    self.camera_model = exif_info[:camera_model] if exif_info[:camera_model]
    self.taken_at = exif_info[:date_time_original] if exif_info[:date_time_original]
    self.latitude = exif_info[:gps_latitude] if exif_info[:gps_latitude]
    self.longitude = exif_info[:gps_longitude] if exif_info[:gps_longitude]
  end

  def generate_thumbnail
    return unless file_path.present?
    
    thumbnail_size = calculate_thumbnail_size
    self.thumbnail_width = thumbnail_size[:width]
    self.thumbnail_height = thumbnail_size[:height]
    self.thumbnail_path = generate_thumbnail_path
    
    # Create thumbnail directory if it doesn't exist
    thumbnail_dir = File.dirname(thumbnail_path)
    FileUtils.mkdir_p(thumbnail_dir) unless Dir.exist?(thumbnail_dir)
    
    # Generate thumbnail using ImageProcessing
    # This will be implemented when you're ready to process actual images
    
    save if changed?
  end
end
