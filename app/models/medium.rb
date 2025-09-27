class Medium < ApplicationRecord
  belongs_to :mediable, polymorphic: true
  belongs_to :uploaded_by, class_name: 'User'
  belongs_to :user
  
  # Enum for medium types
  enum :medium_type, {
    photo: 'photo',
    audio: 'audio', 
    video: 'video'
  }
  
  # Validations for generic media attributes
  validates :file_path, presence: true, uniqueness: true
  validates :md5_hash, presence: true, uniqueness: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }
  validates :original_filename, presence: true
  validates :content_type, presence: true
  validates :medium_type, presence: true
  
  # Content type validation based on medium type
  validates :content_type, inclusion: {
    in: ->(medium) { 
      case medium.medium_type
      when 'photo'
        %w[image/jpeg image/jpg image/png image/gif image/bmp image/tiff image/heic image/heif]
      when 'audio'
        %w[audio/mpeg audio/mp3 audio/wav audio/aac audio/ogg audio/flac]
      when 'video'
        %w[video/mp4 video/mov video/avi video/mkv video/webm]
      else
        []
      end
    },
    message: 'must be a valid format for the medium type'
  }

  def self.ransackable_attributes(auth_object = nil)
    ["content_type", "created_at", "file_path", "file_size", "height", "id", 
     "md5_hash", "medium_type", "original_filename", "taken_at", "updated_at", 
     "uploaded_by_id", "user_id", "width"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["mediable", "uploaded_by", "user"]
  end

  # Scopes
  scope :by_date, -> { order(:taken_at, :created_at) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(medium_type: type) }
  scope :photos, -> { where(medium_type: 'photo') }
  scope :audio, -> { where(medium_type: 'audio') }
  scope :video, -> { where(medium_type: 'video') }

  # Class methods
  def self.duplicate_by_hash(hash)
    find_by(md5_hash: hash)
  end

  def self.total_storage_size
    sum(:file_size)
  end

  # Instance methods
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

  # Delegate methods to mediable object for convenience
  def title
    mediable&.title
  end

  def description  
    mediable&.description
  end
  
  # Check if file exists
  def file_exists?
    file_path.present? && File.exist?(file_path)
  end

  # Generic post-processing status check
  # Delegates to mediable's post_processed? method if available
  def post_processed?
    if mediable.present? && mediable.respond_to?(:post_processed?)
      mediable.post_processed?
    else
      # Default fallback - assume processed if mediable exists
      mediable.present?
    end
  end

  # Class method to create medium from uploaded file
  def self.create_from_uploaded_file(uploaded_file, user, medium_type = nil, post_process: true, batch_id: nil, session_id: nil)
    upload_started_at = Time.current
    
    # Determine medium type if not specified
    medium_type ||= determine_medium_type_from_content_type(uploaded_file.content_type)
    
    unless medium_type
      return { error: "Unsupported file type: #{uploaded_file.content_type}" }
    end
    
    # Generate unique file path
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    random_suffix = SecureRandom.hex(4)
    file_extension = File.extname(uploaded_file.original_filename)
    stored_filename = "#{timestamp}_#{random_suffix}#{file_extension}"
    
    # Create upload directory based on medium type
    upload_dir = Rails.root.join('storage', medium_type.pluralize)
    FileUtils.mkdir_p(upload_dir) unless Dir.exist?(upload_dir)
    
    # Full file path
    file_path = upload_dir.join(stored_filename).to_s
    
    # Save file to disk
    save_uploaded_file_to_path(uploaded_file, file_path)
    
    # Calculate MD5 hash
    md5_hash = Digest::MD5.file(file_path).hexdigest
    
    # Check for duplicates
    existing_medium = find_by(md5_hash: md5_hash)
    if existing_medium
      File.delete(file_path) # Clean up duplicate file
      return { error: "Duplicate file already exists", existing: existing_medium }
    end
    
    upload_completed_at = Time.current
    
    # Extract dimensions for images/videos
    width, height = extract_dimensions(file_path, uploaded_file.content_type)
    
    # Create the specific media type record first
    mediable = create_mediable_record(medium_type, uploaded_file, user)
    return { error: "Failed to create #{medium_type} record" } unless mediable
    
    # Create Medium record with timing information
    medium = new(
      file_path: file_path,
      file_size: File.size(file_path),
      original_filename: uploaded_file.original_filename,
      content_type: uploaded_file.content_type,
      md5_hash: md5_hash,
      width: width,
      height: height,
      medium_type: medium_type,
      mediable: mediable,
      uploaded_by: user,
      user: user,
      upload_started_at: upload_started_at,
      upload_completed_at: upload_completed_at,
      upload_batch_id: batch_id,
      upload_session_id: session_id
    )
    
    if medium.save
      # The mediable association is already set in the medium creation above
      
      # Process type-specific metadata if requested
      Rails.logger.info "🔍 Post-process parameter: #{post_process} for: #{medium.original_filename}"
      if post_process
        processing_started_at = Time.current
        medium.update!(processing_started_at: processing_started_at)
        
        Rails.logger.info "🔄 Starting post-processing for: #{medium.original_filename}"
        begin
          post_process_media(medium)
          Rails.logger.info "✅ Post-processing completed for: #{medium.original_filename}"
          medium.update!(processing_completed_at: Time.current)
        rescue => e
          Rails.logger.error "❌ Post-processing failed for #{medium.original_filename}: #{e.message}"
          Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
          medium.update!(processing_completed_at: Time.current)
          # Note: We still return success since the medium was created, just post-processing failed
        end
      else
        Rails.logger.info "⏭️ Skipping post-processing for: #{medium.original_filename}"
      end
      
      { success: true, medium: medium }
    else
      # Clean up files if creation failed
      File.delete(file_path) if File.exist?(file_path)
      mediable.destroy if mediable
      
      error_message = medium.errors.full_messages.join(', ')
      { error: error_message }
    end
  end
  
  # Determine medium type from content type
  def self.determine_medium_type_from_content_type(content_type)
    return nil unless content_type
    
    content_type = content_type.downcase
    
    # Check against Photo valid types
    if defined?(Photo) && Photo.respond_to?(:valid_types)
      return 'photo' if Photo.valid_types.key?(content_type)
    end
    
    # TODO: Add audio and video checks when those models exist
    # For now, we only support photos
    
    nil
  end
  
  # Filter files by acceptable types for import
  def self.filter_acceptable_files(files, allowed_types = ['all'])
    return [] if files.empty?
    
    acceptable_types = {}
    valid_extensions = {}
    
    # Build acceptable types from mediable classes
    if allowed_types.include?('all') || allowed_types.include?('photo')
      if defined?(Photo) && Photo.respond_to?(:valid_types)
        Photo.valid_types.each do |mime_type, extensions|
          acceptable_types[mime_type] = 'photo'
          extensions.each { |ext| valid_extensions[ext] = 'photo' }
        end
      end
    end
    
    # TODO: Add audio and video when those models are created
    # For now, we'll reject audio/video files to prevent errors
    
    # Filter files and return with their determined types
    files.filter_map do |file|
      content_type = file.content_type&.downcase
      extension = File.extname(file.original_filename).downcase
      
      # Check by MIME type first
      medium_type = acceptable_types[content_type]
      
      # Fallback to file extension if content type detection fails
      unless medium_type
        medium_type = valid_extensions[extension]
      end
      
      if medium_type
        {
          file: file,
          medium_type: medium_type,
          content_type: content_type,
          extension: extension
        }
      else
        Rails.logger.warn "Skipping unsupported file: #{file.original_filename} (#{content_type}, #{extension})"
        nil
      end
    end
  end

  private

  def self.save_uploaded_file_to_path(uploaded_file, file_path)
    if uploaded_file.respond_to?(:tempfile) && uploaded_file.tempfile
      FileUtils.copy_file(uploaded_file.tempfile.path, file_path)
    else
      File.open(file_path, 'wb') do |f|
        f.write(uploaded_file.read)
      end
    end
  end

  def self.extract_dimensions(file_path, content_type)
    return [nil, nil] unless content_type.start_with?('image/', 'video/')
    
    begin
      require 'mini_magick'
      image = MiniMagick::Image.open(file_path)
      [image.width, image.height]
    rescue => e
      Rails.logger.debug "Could not extract dimensions from #{file_path}: #{e.message}"
      [nil, nil]
    end
  end

  def self.create_mediable_record(medium_type, uploaded_file, user)
    case medium_type
    when 'photo'
      Photo.create(
        title: File.basename(uploaded_file.original_filename, '.*').humanize,
        description: nil
      )
    when 'audio'
      # Audio.create(...) when we add Audio model
      nil # For now
    when 'video'
      # Video.create(...) when we add Video model  
      nil # For now
    end
  end

  # Post-process media after upload (EXIF, thumbnails, etc.)
  def self.post_process_media(medium)
    Rails.logger.info "Post-processing #{medium.medium_type}: #{medium.original_filename}"
    
    case medium.medium_type
    when 'photo'
      # Trigger EXIF extraction and thumbnail generation
      if medium.mediable&.respond_to?(:extract_metadata_from_exif, true)
        photo = medium.mediable
        photo.send(:extract_metadata_from_exif)
        # Use update_columns to bypass callbacks and avoid infinite loop
        photo.update_columns(
          exif_data: photo.exif_data,
          camera_make: photo.camera_make,
          camera_model: photo.camera_model,
          latitude: photo.latitude,
          longitude: photo.longitude
        )
      end
      medium.mediable.generate_thumbnail if medium.mediable&.respond_to?(:generate_thumbnail)
    when 'audio'
      # Extract audio metadata when we add audio support
    when 'video'
      # Extract video metadata when we add video support
    end
    
    Rails.logger.info "Post-processing completed for: #{medium.original_filename}"
  end

  # Legacy method name for backwards compatibility
  def self.process_medium_metadata(medium)
    post_process_media(medium)
  end

  # Batch post-process media that were uploaded without processing
  def self.batch_post_process_media(medium_ids = nil)
    media_to_process = medium_ids ? where(id: medium_ids) : all
    
    Rails.logger.info "Starting batch post-processing for #{media_to_process.count} media files"
    
    processed_count = 0
    errors = []
    
    media_to_process.find_each do |medium|
      begin
        post_process_media(medium)
        processed_count += 1
      rescue => e
        error_msg = "#{medium.original_filename}: #{e.message}"
        errors << error_msg
        Rails.logger.error "Failed to post-process #{medium.original_filename}: #{e.message}"
      end
    end
    
    Rails.logger.info "Batch post-processing completed. Processed: #{processed_count}, Errors: #{errors.length}"
    { processed_count: processed_count, errors: errors }
  end

end