class Photo < ApplicationRecord
  has_one :medium, as: :mediable, dependent: :destroy
  
  has_many :photo_albums, dependent: :destroy
  has_many :albums, through: :photo_albums
  has_one :cover_album, class_name: 'Album', foreign_key: 'cover_photo_id'

  # Validations for photo-specific attributes
  validates :latitude, :longitude, numericality: true, allow_nil: true
  
  # Delegate generic media attributes to Medium
  delegate :file_path, :file_size, :original_filename, :content_type, :md5_hash,
           :width, :height, :taken_at, :uploaded_by, :user, :file_size_human,
           :taken_date, :file_exists?, to: :medium, allow_nil: true
           
  # Note: Medium creates Photo, not the other way around

  def self.ransackable_attributes(auth_object = nil)
    ["camera_make", "camera_model", "created_at", "description", "exif_data", 
     "id", "latitude", "longitude", "thumbnail_height", "thumbnail_path", 
     "thumbnail_width", "title", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["albums", "medium"]
  end

  # Scopes  
  scope :recent, -> { order(created_at: :desc) }
  scope :with_location, -> { where.not(latitude: nil, longitude: nil) }
  scope :by_camera, ->(make, model = nil) { 
    query = where(camera_make: make)
    query = query.where(camera_model: model) if model
    query
  }
  
  # Scopes that work with Medium
  scope :by_date, -> { joins(:medium).order('media.taken_at, media.created_at') }
  scope :by_file_type, ->(type) { joins(:medium).where(media: { content_type: type }) }

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
    return {} unless File.exist?(file_path)
    
    begin
      case medium&.content_type
      when 'image/jpeg', 'image/jpg'
        require 'exifr/jpeg'
        exif = EXIFR::JPEG.new(file_path)
        return {} unless exif
        exif.to_hash
      when 'image/tiff'
        require 'exifr/tiff'
        exif = EXIFR::TIFF.new(file_path)
        return {} unless exif
        exif.to_hash
      when 'image/heic', 'image/heif'
        # HEIC files require different approach - use MiniMagick to extract EXIF
        extract_heic_exif(file_path)
      else
        return {}
      end
    rescue => e
      Rails.logger.error "Failed to extract EXIF from #{file_path}: #{e.message}"
      {}
    end
  end

  def extract_heic_exif(file_path)
    require 'mini_magick'
    
    begin
      image = MiniMagick::Image.open(file_path)
      
      # Get ALL EXIF data at once using the bulk method
      # This avoids the warnings from trying to access non-existent properties
      exif_data = {}
      
      begin
        # Use image.exif to get all available EXIF data without warnings
        all_exif = image.exif
        exif_data = all_exif if all_exif.is_a?(Hash)
      rescue => e
        Rails.logger.debug "Bulk EXIF extraction failed for #{file_path}, trying identify method: #{e.message}"
        
        # Fallback: use identify command to get EXIF data
        begin
          # Get raw EXIF output from identify command
          result = image.run_command("identify", "-format", "%[EXIF:*]", image.path)
          
          # Parse the EXIF output manually if needed
          if result && !result.empty?
            # This gets a text dump of all EXIF data
            # Parse it into a hash structure
            lines = result.split("\n")
            lines.each do |line|
              if line.include?("=")
                key, value = line.split("=", 2)
                key = key.strip.gsub(/^exif:/, '') # Remove exif: prefix
                exif_data[key] = value.strip unless value.nil? || value.strip.empty?
              end
            end
          end
        rescue => identify_error
          Rails.logger.debug "Identify EXIF extraction also failed for #{file_path}: #{identify_error.message}"
        end
      end
      
      # If we still don't have data, try the safe property access method
      # but only for essential fields and with proper error handling
      if exif_data.empty?
        Rails.logger.debug "Trying safe property access for #{file_path}"
        safe_exif_fields = %w[Make Model DateTimeOriginal]
        
        safe_exif_fields.each do |field|
          begin
            value = image["exif:#{field}"]
            exif_data[field] = value if value && !value.empty?
          rescue => field_error
            # Silently skip fields that don't exist or cause errors
            Rails.logger.debug "Skipping EXIF field #{field} for #{file_path}: #{field_error.message}"
          end
        end
      end
      
      exif_data.compact
    rescue => e
      Rails.logger.error "Failed to extract HEIC EXIF from #{file_path}: #{e.message}"
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

  # Debug method to see all available EXIF fields
  def debug_all_exif_fields
    return "No file path" unless file_path.present? && File.exist?(file_path)
    
    begin
      require 'exifr/jpeg'
      exif = EXIFR::JPEG.new(file_path)
      return "No EXIF data" unless exif
      
      # Get all available methods/fields
      all_fields = exif.to_hash.keys.sort
      result = "Available EXIF fields (#{all_fields.count}):\n"
      
      all_fields.each do |field|
        value = exif.to_hash[field]
        result += "#{field}: #{value.inspect}\n"
      end
      
      result
    rescue => e
      "Error reading EXIF: #{e.message}"
    end
  end

  def taken_date
    taken_at || created_at
  end

  private


  def extract_metadata_from_exif
    return unless medium&.file_path&.present?
    
    exif_info = extract_exif_data(medium.file_path)
    self.exif_data = exif_info
    
    # Extract specific fields from the complete EXIF hash for database columns
    # This allows for efficient querying while preserving all metadata
    self.camera_make = exif_info['Make'] if exif_info['Make']
    self.camera_model = exif_info['Model'] if exif_info['Model']
    
    # Set taken_at on the medium record
    if exif_info['DateTimeOriginal'] && medium
      medium.update_column(:taken_at, exif_info['DateTimeOriginal'])
    end
    
    # GPS coordinates are photo-specific and stay on the photo record
    self.latitude = extract_gps_coordinate(exif_info, 'GPSLatitude', exif_info['GPSLatitudeRef'])
    self.longitude = extract_gps_coordinate(exif_info, 'GPSLongitude', exif_info['GPSLongitudeRef'])
  end

  def extract_gps_coordinate(exif_hash, coord_key, ref_key)
    coord = exif_hash[coord_key]
    ref = exif_hash[ref_key]
    
    return nil unless coord && ref
    
    # Handle different coordinate formats that might be in EXIF
    case coord
    when Numeric
      ref == 'S' || ref == 'W' ? -coord : coord
    when Array
      # DMS format [degrees, minutes, seconds]
      decimal = coord[0] + coord[1]/60.0 + coord[2]/3600.0
      ref == 'S' || ref == 'W' ? -decimal : decimal
    else
      coord
    end
  rescue
    nil
  end

  def generate_thumbnail
    return unless file_path.present? && File.exist?(file_path)
    
    begin
      thumbnail_size = calculate_thumbnail_size
      self.thumbnail_width = thumbnail_size[:width]
      self.thumbnail_height = thumbnail_size[:height]
      self.thumbnail_path = generate_thumbnail_path
      
      # Create thumbnail directory if it doesn't exist
      thumbnail_dir = File.dirname(thumbnail_path)
      FileUtils.mkdir_p(thumbnail_dir) unless Dir.exist?(thumbnail_dir)
      
      # Generate thumbnail using MiniMagick
      require 'mini_magick'
      
      # Open the original image
      image = MiniMagick::Image.open(file_path)
      
      # Resize to thumbnail dimensions while maintaining aspect ratio
      image.resize "#{thumbnail_size[:width]}x#{thumbnail_size[:height]}>"
      
       # Convert HEIC to JPEG for better browser compatibility
       if medium&.content_type&.include?('heic') || medium&.content_type&.include?('heif')
        # Change extension to .jpg for HEIC files
        self.thumbnail_path = thumbnail_path.gsub(/\.(heic|heif)$/i, '.jpg')
        image.format 'jpg'
      end
      
      # Write the thumbnail file
      image.write(thumbnail_path)
      
      Rails.logger.info "Generated thumbnail: #{thumbnail_path}"
      
      save if changed?
      
    rescue => e
      Rails.logger.error "Failed to generate thumbnail for #{file_path}: #{e.message}"
      # Clear thumbnail fields on failure
      self.thumbnail_path = nil
      self.thumbnail_width = nil
      self.thumbnail_height = nil
      save if changed?
    end
  end
end
