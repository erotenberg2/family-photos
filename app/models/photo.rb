class Photo < ApplicationRecord
  # Image size constants
  THUMBNAIL_MAX_SIZE = 128  # Small thumbnails for index pages
  PREVIEW_MAX_SIZE = 400    # Larger previews for show pages
  
  # Define valid file types for photos
  def self.valid_types
    {
      # Standard MIME types => file extensions
      'image/jpeg' => ['.jpg', '.jpeg'],
      'image/jpg' => ['.jpg'],                    # Non-standard but used by some systems
      'image/pjpeg' => ['.jpg', '.jpeg'],         # Progressive JPEG (Internet Explorer)
      'image/png' => ['.png'],
      'image/x-png' => ['.png'],                  # Alternative PNG MIME type
      'image/gif' => ['.gif'],
      'image/bmp' => ['.bmp'],
      'image/x-ms-bmp' => ['.bmp'],              # Microsoft BMP variant
      'image/tiff' => ['.tiff', '.tif'],
      'image/x-tiff' => ['.tiff', '.tif'],       # Alternative TIFF MIME type
      'image/heic' => ['.heic'],
      'image/heif' => ['.heif'],
      'image/webp' => ['.webp'],
      'image/svg+xml' => ['.svg'],               # SVG support
      'image/x-icon' => ['.ico'],                # ICO files
      'image/vnd.microsoft.icon' => ['.ico']     # Microsoft ICO variant
    }
  end
  
  has_one :medium, as: :mediable, dependent: :destroy
  
  has_many :photo_albums, dependent: :destroy
  has_many :albums, through: :photo_albums
  has_one :cover_album, class_name: 'Album', foreign_key: 'cover_photo_id'

  # Validations for photo-specific attributes
  validates :latitude, :longitude, numericality: true, allow_nil: true
  
  # Delegate generic media attributes to Medium
  delegate :file_path, :file_size, :original_filename, :content_type, :md5_hash,
           :taken_at, :uploaded_by, :user, :file_size_human,
           :taken_date, :file_exists?, to: :medium, allow_nil: true
           
  # Note: Medium creates Photo, not the other way around

  def self.ransackable_attributes(auth_object = nil)
    ["camera_make", "camera_model", "created_at", "description", "exif_data", 
     "height", "id", "latitude", "longitude", "preview_height", "preview_path", 
     "preview_width", "thumbnail_height", "thumbnail_path", 
     "thumbnail_width", "title", "updated_at", "width"]
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

  # Callbacks removed - all processing now handled explicitly in post-processing
  # before_save :extract_metadata_from_exif
  # after_create :generate_thumbnail
  
  # Intrinsic datetime method - returns the datetime from EXIF data
  def datetime_intrinsic
    return nil unless exif_data.present?
    
    # Try to get datetime from EXIF data
    exif_datetime = exif_data[:date_time_original] || exif_data['date_time_original']
    
    if exif_datetime.present?
      # Parse the EXIF datetime string (usually in format "YYYY:MM:DD HH:MM:SS")
      begin
        Time.strptime(exif_datetime, "%Y:%m:%d %H:%M:%S")
      rescue ArgumentError
        # Try alternative formats if the standard format fails
        begin
          Time.parse(exif_datetime)
        rescue ArgumentError
          nil
        end
      end
    else
      nil
    end
  end

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
    calculate_size_for_max_dimension(THUMBNAIL_MAX_SIZE)
  end

  def calculate_preview_size
    calculate_size_for_max_dimension(PREVIEW_MAX_SIZE)
  end

  private

  def calculate_size_for_max_dimension(max_size)
    return { width: max_size, height: max_size } unless width && height
    
    # Calculate dimensions maintaining aspect ratio
    if width > height
      # Landscape
      new_width = [width, max_size].min
      new_height = (new_width.to_f * height / width).round
    else
      # Portrait or square
      new_height = [height, max_size].min
      new_width = (new_height.to_f * width / height).round
    end
    
    { width: new_width, height: new_height }
  end

  public

  def generate_thumbnail_path
    return nil unless file_path
    
    dir = File.dirname(file_path)
    ext = File.extname(file_path)
    base = File.basename(file_path, ext)
    
    File.join(dir, "thumbs", "#{base}_thumb#{ext}")
  end

  def generate_preview_path
    return nil unless file_path
    
    dir = File.dirname(file_path)
    ext = File.extname(file_path)
    base = File.basename(file_path, ext)
    
    File.join(dir, "previews", "#{base}_preview#{ext}")
  end

  def has_location?
    latitude.present? && longitude.present?
  end

  # Override Medium's post_processed? to check for thumbnail and preview
  def post_processed?
    thumbnail_path.present? && File.exist?(thumbnail_path) &&
    preview_path.present? && File.exist?(preview_path)
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

  def generate_thumbnail
    return unless file_path.present? && File.exist?(file_path)
    
    begin
      require 'mini_magick'
      
      # Generate thumbnail (small, for index pages)
      generate_image_variant(:thumbnail)
      
      # Generate preview (larger, for show pages)  
      generate_image_variant(:preview)
      
      Rails.logger.info "Generated thumbnail and preview for: #{file_path}"
      
      save if changed?
      
    rescue => e
      Rails.logger.error "Failed to generate thumbnail/preview for #{file_path}: #{e.message}"
      # Clear all generated image fields on failure
      self.thumbnail_path = nil
      self.thumbnail_width = nil
      self.thumbnail_height = nil
      self.preview_path = nil
      self.preview_width = nil
      self.preview_height = nil
      save if changed?
    end
  end

  private


  def extract_metadata_from_exif
    return unless medium&.file_path&.present?
    
    exif_info = extract_exif_data(medium.file_path)
    self.exif_data = exif_info
    
    # Extract specific fields from the complete EXIF hash for database columns
    # This allows for efficient querying while preserving all metadata
    self.camera_make = exif_info[:make] if exif_info[:make]
    self.camera_model = exif_info[:model] if exif_info[:model]
    
    # Set taken_at on the medium record
    if exif_info[:date_time_original] && medium
      medium.update_column(:taken_at, exif_info[:date_time_original])
    end
    
    # GPS coordinates are photo-specific and stay on the photo record
    # Handle both string and symbol keys for GPS data
    gps_lat_key = exif_info.key?('GPSLatitude') ? 'GPSLatitude' : :gps_latitude
    gps_lon_key = exif_info.key?('GPSLongitude') ? 'GPSLongitude' : :gps_longitude
    gps_lat_ref_key = exif_info.key?('GPSLatitudeRef') ? 'GPSLatitudeRef' : :gps_latitude_ref
    gps_lon_ref_key = exif_info.key?('GPSLongitudeRef') ? 'GPSLongitudeRef' : :gps_longitude_ref
    
    self.latitude = extract_gps_coordinate(exif_info, gps_lat_key, exif_info[gps_lat_ref_key])
    self.longitude = extract_gps_coordinate(exif_info, gps_lon_key, exif_info[gps_lon_ref_key])
    
    # Note: Changes are saved by explicit update_columns call in post-processing
  end

  def extract_gps_coordinate(exif_hash, coord_key, ref_value)
    coord = exif_hash[coord_key]
    ref = ref_value
    
    
    return nil unless coord && ref
    
    # Handle different coordinate formats that might be in EXIF
    case coord
    when Numeric
      result = ref == 'S' || ref == 'W' ? -coord : coord
      result
    when Array
      # DMS format [degrees, minutes, seconds]
      decimal = coord[0] + coord[1]/60.0 + coord[2]/3600.0
      result = ref == 'S' || ref == 'W' ? -decimal : decimal
      result
    when String
      # Handle HEIC format like "37/1,52/1,675/100" (degrees/minutes/seconds with fractions)
      result = parse_heic_gps_string(coord, ref)
      result
    else
      coord
    end
  rescue => e
    Rails.logger.error "GPS extraction error: #{e.message}"
    nil
  end

  private

  # Parse HEIC GPS coordinate string format like "37/1,52/1,675/100"
  def parse_heic_gps_string(coord_string, ref)
    # Split by comma to get degrees, minutes, seconds components
    parts = coord_string.split(',')
    return nil unless parts.length == 3
    
    # Parse each component (e.g., "37/1" -> 37.0, "675/100" -> 6.75)
    degrees = parse_fraction(parts[0])
    minutes = parse_fraction(parts[1]) 
    seconds = parse_fraction(parts[2])
    
    return nil unless degrees && minutes && seconds
    
    # Convert to decimal degrees
    decimal = degrees + minutes/60.0 + seconds/3600.0
    
    # Apply hemisphere reference
    ref == 'S' || ref == 'W' ? -decimal : decimal
  rescue => e
    Rails.logger.error "Failed to parse HEIC GPS string '#{coord_string}': #{e.message}"
    nil
  end
  
  # Parse fraction string like "37/1" or "675/100"
  def parse_fraction(fraction_string)
    return nil unless fraction_string
    
    if fraction_string.include?('/')
      numerator, denominator = fraction_string.split('/').map(&:to_f)
      return nil if denominator == 0
      numerator / denominator
    else
      fraction_string.to_f
    end
  end

  def generate_image_variant(variant_type)
    # Calculate size and paths based on variant type
    size = variant_type == :thumbnail ? calculate_thumbnail_size : calculate_preview_size
    path = variant_type == :thumbnail ? generate_thumbnail_path : generate_preview_path
    
    # Set attributes
    if variant_type == :thumbnail
      self.thumbnail_width = size[:width]
      self.thumbnail_height = size[:height]
      self.thumbnail_path = path
    else
      self.preview_width = size[:width]
      self.preview_height = size[:height]
      self.preview_path = path
    end
    
    # Create directory if it doesn't exist
    dir = File.dirname(path)
    FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    
    # Open and resize image
    image = MiniMagick::Image.open(file_path)
    image.resize "#{size[:width]}x#{size[:height]}>"
    
    # Convert HEIC to JPEG for better browser compatibility
    if medium&.content_type&.include?('heic') || medium&.content_type&.include?('heif')
      # Change extension to .jpg for HEIC files
      path = path.gsub(/\.(heic|heif)$/i, '.jpg')
      if variant_type == :thumbnail
        self.thumbnail_path = path
      else
        self.preview_path = path
      end
      image.format 'jpg'
    end
    
    # Write the image file
    image.write(path)
  end

  public
end
