class Video < ApplicationRecord
  # Image size constants for video thumbnails
  THUMBNAIL_MAX_SIZE = 128  # Small thumbnails for index pages
  PREVIEW_MAX_SIZE = 400    # Larger previews for show pages
  
  # Define valid file types for videos - make sure this matches the media_import_popup.js file
  def self.valid_types
    {
      # Standard MIME types => file extensions
      'video/mp4' => ['.mp4'],
      'video/x-m4v' => ['.m4v'],
      'video/mp4v-es' => ['.mp4'],
      'video/quicktime' => ['.mov', '.qt'],
      'video/x-quicktime' => ['.mov', '.qt'],
      'video/avi' => ['.avi'],
      'video/x-msvideo' => ['.avi'],
      'video/msvideo' => ['.avi'],
      'video/mkv' => ['.mkv'],
      'video/x-matroska' => ['.mkv'],
      'video/webm' => ['.webm'],
      'video/x-ms-wmv' => ['.wmv'],
      'video/wmv' => ['.wmv'],  # Alternative MIME type
      'video/x-ms-asf' => ['.asf'],
      'video/flv' => ['.flv'],
      'video/x-flv' => ['.flv']
    }
  end
  
  # Define auxiliary file extensions that should be attached to video files
  def self.auxiliary_file_extensions
    [
      '.xml',   # Metadata files (XMP, editing decisions, etc.)
      '.srt',   # Subtitle files
      '.sub',   # Subtitle files
      '.vtt',   # WebVTT subtitle files
      '.idx',   # VOBSUB subtitle index
      '.ass',   # Advanced subtitle format
      '.ssa'    # SubStation Alpha subtitle format
    ]
  end
  
  has_one :medium, as: :mediable, dependent: :destroy
  
  # Delegate generic media attributes to Medium
  delegate :file_size, :original_filename, :current_filename, :content_type, :md5_hash,
           :uploaded_by, :user, :file_size_human, :effective_datetime,
           :has_valid_datetime?, :datetime_source, :file_exists?, to: :medium, allow_nil: true
           
  # Note: Medium creates Video, not the other way around

  def self.ransackable_attributes(auth_object = nil)
    ["bitrate", "camera_make", "camera_model", "created_at", "description", "duration", 
     "height", "id", "metadata", "preview_height", "preview_path", "preview_width", 
     "thumbnail_height", "thumbnail_path", "thumbnail_width", "title", "updated_at", "width"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["medium"]
  end

  # Scopes  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_dimensions, ->(width, height) { where(width: width, height: height) }
  scope :by_camera, ->(make, model = nil) { 
    query = where(camera_make: make)
    query = query.where(camera_model: model) if model
    query
  }
  
  # Scopes that work with Medium
  scope :by_date, -> { joins(:medium).order('media.datetime_user, media.datetime_intrinsic, media.datetime_inferred, media.created_at') }
  scope :by_file_type, ->(type) { joins(:medium).where(media: { content_type: type }) }

  # Intrinsic datetime from metadata (for future implementation)
  def datetime_intrinsic
    # TODO: Extract datetime from video metadata when video metadata extraction is implemented
    nil
  end

  # Check if post-processing has been completed
  def post_processed?
    # Video post-processing completed if dimensions are set
    # Thumbnail is optional - it may not exist if ffmpeg fails, but that's still "processed"
    width.present? && height.present?
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
    return nil unless medium&.current_filename
    
    require_relative '../../lib/constants'
    ext = '.jpg'  # Video thumbnails are always JPEG
    # Always use main filename for thumbnail paths (consistent regardless of primary version)
    base = File.basename(medium.current_filename, File.extname(medium.current_filename))
    
    File.join(Constants::THUMBNAILS_STORAGE, "#{base}_thumb#{ext}")
  end

  def generate_preview_path
    return nil unless medium&.current_filename
    
    require_relative '../../lib/constants'
    ext = '.jpg'  # Video previews are always JPEG
    # Always use main filename for preview paths (consistent regardless of primary version)
    base = File.basename(medium.current_filename, File.extname(medium.current_filename))
    
    File.join(Constants::PREVIEWS_STORAGE, "#{base}_preview#{ext}")
  end

  # Generate thumbnail from video
  def generate_thumbnail
    # Use primary file path if set, otherwise main file path
    source_path = medium.source_file_path_for_thumbnails || medium.full_file_path
    return unless source_path.present? && File.exist?(source_path)
    
    begin
      require 'mini_magick'
      
      # First, extract video dimensions if not already set
      extract_dimensions_from_ffprobe unless width.present? && height.present?
      
      # Generate thumbnail (small, for index pages)
      generate_video_variant(:thumbnail)
      
      # Generate preview (larger, for show pages)  
      generate_video_variant(:preview)
      
      Rails.logger.info "Generated thumbnail and preview for: #{medium.full_file_path}"
      
      save if changed?
      
    rescue => e
      Rails.logger.error "Failed to generate thumbnail/preview for #{medium.full_file_path}: #{e.message}"
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

  # Extract video dimensions from file using ffprobe
  def extract_dimensions_from_ffprobe
    return unless medium&.full_file_path.present? && File.exist?(medium.full_file_path)
    
    begin
      require 'open3'
      
      # Use ffprobe to get video dimensions
      ffprobe_cmd = [
        'ffprobe',
        '-v', 'error',
        '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height',
        '-of', 'json',
        medium.full_file_path
      ]
      
      stdout, stderr, status = Open3.capture3(*ffprobe_cmd)
      
      if status.success? && stdout.present?
        data = JSON.parse(stdout)
        streams = data['streams']
        if streams && streams.first
          self.width = streams.first['width']
          self.height = streams.first['height']
          Rails.logger.info "Extracted video dimensions: #{self.width}x#{self.height} from #{medium.full_file_path}"
        end
      else
        Rails.logger.error "FFprobe failed to extract dimensions: #{stderr}"
      end
    rescue => e
      Rails.logger.error "Exception extracting video dimensions: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  # Extract description from video metadata
  # For now, returns empty string since video metadata extraction is not yet fully implemented
  def extract_description_from_metadata
    # TODO: Extract description from video metadata when video metadata extraction is implemented
    # Could use ffprobe to get tags like 'description', 'comment', etc. similar to audio
    ""
  end

  def generate_video_variant(variant_type)
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
    
    # Extract frame from video and create thumbnail
    # Note: This requires ffmpeg to be installed on the system
    require 'open3'
    
    # Use ffmpeg to extract a frame from the video
    # Use primary file path if set, otherwise main file path
    source_path = medium.source_file_path_for_thumbnails || medium.full_file_path
    # Try to get a frame from 10% into the video (more likely to be non-black)
    ffmpeg_cmd = [
      'ffmpeg',
      '-i', source_path,
      '-ss', '00:00:01',  # Seek to 1 second
      '-vframes', '1',     # Extract 1 frame
      '-vf', "scale=#{size[:width]}:-1",  # Scale to target width, maintain aspect ratio
      '-y',                # Overwrite output file
      path
    ]
    
    stdout, stderr, status = Open3.capture3(*ffmpeg_cmd)
    
    if status.success?
      Rails.logger.info "Extracted video thumbnail: #{path}"
    else
      Rails.logger.error "FFmpeg failed: #{stderr}"
      raise "Failed to extract video thumbnail"
    end
  rescue => e
    Rails.logger.error "Exception generating video variant: #{e.message}"
    raise
  end

  public

  # Duration in human-readable format
  def duration_human
    return nil unless duration.present?
    
    seconds = duration
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60
    
    if hours > 0
      format("%d:%02d:%02d", hours, minutes, secs)
    else
      format("%d:%02d", minutes, secs)
    end
  end

  # Bitrate in human-readable format (kbps)
  def bitrate_human
    return nil unless bitrate.present?
    "#{bitrate} kbps"
  end
  
  # Attach auxiliary files (XML, subtitles) to this video file by moving them to aux/attachments/
  # Looks for auxiliary files in the same directory with matching base filename
  def attach_auxiliary_files
    return unless medium&.full_file_path.present?
    
    main_file_path = medium.full_file_path
    main_dir = File.dirname(main_file_path)
    main_filename = File.basename(main_file_path)
    main_base = File.basename(main_file_path, File.extname(main_file_path))
    
    # Extract the original base name (after timestamp prefix if present)
    original_base = main_base
    if main_base =~ /^\d{8}_\d{6}-(.+)$/
      original_base = $1
    end
    
    # Get auxiliary file extensions
    aux_extensions = self.class.auxiliary_file_extensions
    
    # Find matching auxiliary files in the same directory
    aux_files = aux_extensions.flat_map do |ext|
      patterns = [
        File.join(main_dir, "#{main_base}#{ext}"),
        File.join(main_dir, "#{main_base.split('-').first}-#{original_base}#{ext}"),
        File.join(main_dir, "#{original_base}#{ext}")
      ]
      
      patterns.flat_map do |pattern|
        Dir.glob(pattern).select { |f| File.file?(f) && f != main_file_path }
      end
    end.uniq
    
    return if aux_files.empty?
    
    # Ensure aux folder exists
    attachments_folder = medium.attachments_folder_path
    return unless attachments_folder.present?
    
    FileUtils.mkdir_p(attachments_folder) unless Dir.exist?(attachments_folder)
    
    # Move auxiliary files to attachments folder
    aux_files.each do |aux_file|
      aux_filename = File.basename(aux_file)
      # Use original base name for the stored filename (remove timestamp prefix if present)
      stored_name = aux_filename
      if aux_filename =~ /^\d{8}_\d{6}-(.+)$/
        stored_name = $1
      end
      dest_path = File.join(attachments_folder, stored_name)
      
      # Handle filename conflicts
      if File.exist?(dest_path)
        base_name = File.basename(stored_name, File.extname(stored_name))
        ext = File.extname(stored_name)
        counter = 1
        loop do
          new_name = "#{base_name}-#{counter}#{ext}"
          dest_path = File.join(attachments_folder, new_name)
          break unless File.exist?(dest_path)
          counter += 1
        end
      end
      
      begin
        FileUtils.mv(aux_file, dest_path)
        Rails.logger.info "📎 Attached auxiliary file: #{aux_filename} -> #{File.basename(dest_path)}"
      rescue => e
        Rails.logger.error "❌ Failed to attach auxiliary file #{aux_filename}: #{e.message}"
      end
    end
  end
end

