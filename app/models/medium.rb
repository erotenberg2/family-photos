class Medium < ApplicationRecord
  belongs_to :mediable, polymorphic: true
  belongs_to :uploaded_by, class_name: 'User'
  belongs_to :user
  belongs_to :event, optional: true
  belongs_to :subevent, optional: true
  
  # Enum for medium types
  enum :medium_type, {
    photo: 'photo',
    audio: 'audio', 
    video: 'video'
  }
  
  # Enum for storage classes
  enum :storage_class, {
    unsorted: 'unsorted',
    daily: 'daily',
    event: 'event'
  }
  
  # Validations for generic media attributes
  validates :file_path, presence: true
  validates :current_filename, presence: true, uniqueness: true
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

  # Callbacks for file operations
  before_update :rename_file_on_disk, if: :current_filename_changed?
  after_update :rename_file_if_datetime_changed, if: :effective_datetime_changed?

  # Virtual attribute for filename editing
  attr_accessor :descriptive_name

  # Set initial descriptive_name from current_filename
  def descriptive_name
    return @descriptive_name if @descriptive_name.present?
    return "" if current_filename.blank?
    
    # Remove file extension
    name_without_ext = File.basename(current_filename, '.*')
    
    # Extract the part after the first dash (descriptive part)
    if name_without_ext.include?('-')
      parts = name_without_ext.split('-')
      if parts.length > 1
        # Join all parts after the first one (in case there are multiple dashes in the descriptive part)
        parts[1..-1].join('-')
      else
        ""
      end
    else
      ""
    end
  end

  def self.ransackable_attributes(auth_object = nil)
    ["client_file_path", "content_type", "created_at", "current_filename", "datetime_inferred", "datetime_intrinsic", "datetime_source_last_modified", 
     "datetime_user", "event_id", "file_path", "file_size", "id", "latitude", "longitude", "md5_hash", "medium_type", "original_filename", 
     "storage_class", "subevent_id", "updated_at", "uploaded_by_id", "user_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["event", "mediable", "subevent", "uploaded_by", "user"]
  end
  
  # Debug method to find missing files
  def self.find_missing_files
    Rails.logger.info "=== SEARCHING FOR MISSING FILES ==="
    missing_files = []
    
    Medium.all.each do |medium|
      if medium.file_path.present? && medium.current_filename.present?
        unless File.exist?(medium.full_file_path)
          missing_files << {
            id: medium.id,
            original_filename: medium.original_filename,
            file_path: medium.full_file_path,
            storage_class: medium.storage_class,
            event_id: medium.event_id,
            subevent_id: medium.subevent_id
          }
        end
      end
    end
    
    Rails.logger.info "Found #{missing_files.count} missing files:"
    missing_files.each do |missing|
      Rails.logger.info "Medium #{missing[:id]}: #{missing[:original_filename]}"
      Rails.logger.info "  Expected at: #{missing[:file_path]}"
      Rails.logger.info "  Storage class: #{missing[:storage_class]}"
      Rails.logger.info "  Event ID: #{missing[:event_id]}, Subevent ID: #{missing[:subevent_id]}"
    end
    
    Rails.logger.info "=== END SEARCHING FOR MISSING FILES ==="
    missing_files
  end
  
  # Method to search for a file in all storage directories
  def self.search_for_file(filename)
    require_relative '../../lib/constants'
    Rails.logger.info "=== SEARCHING FOR FILE: #{filename} ==="
    
    found_paths = []
    
    # Search in all storage directories
    [Constants::UNSORTED_STORAGE, Constants::DAILY_STORAGE, Constants::EVENTS_STORAGE].each do |storage_base|
      next unless Dir.exist?(storage_base)
      
      Rails.logger.info "Searching in: #{storage_base}"
      
      # Search recursively
      Dir.glob(File.join(storage_base, '**', '*')).each do |file_path|
        next unless File.file?(file_path)
        
        if File.basename(file_path) == filename || File.basename(file_path).include?(File.basename(filename, '.*'))
          found_paths << file_path
          Rails.logger.info "Found: #{file_path}"
        end
      end
    end
    
    Rails.logger.info "Found #{found_paths.count} matching files"
    Rails.logger.info "=== END SEARCHING FOR FILE ==="
    found_paths
  end
  
  # Method to ensure filename uniqueness in the database
  # Uses case-insensitive exact matching (including extension)
  def self.ensure_unique_filename(filename)
    # Check if filename already exists in database (case-insensitive)
    unless is_filename_unique_in_database(filename)
      # Filename exists in database, need to make it unique
      extension = File.extname(filename)
      base_name = File.basename(filename, extension)
      
      # Try adding -(1), -(2), etc.
      counter = 1
      loop do
        new_filename = "#{base_name}-(#{counter})#{extension}"
        
        # Check if this new filename is also unique in database
        if is_filename_unique_in_database(new_filename)
          Rails.logger.info "Filename conflict resolved: #{filename} -> #{new_filename} (database conflict)"
          return new_filename
        end
        
        counter += 1
        break if counter > 1000 # Safety limit
      end
      
      Rails.logger.warn "Could not resolve filename conflict for: #{filename} (database conflict)"
      return filename # Return original if we can't resolve
    end
    
    # Filename is unique in database
    return filename
  end
  
  # Helper method to check if a filename is unique in the database (case-insensitive)
  def self.is_filename_unique_in_database(filename)
    # Check against existing current_filename values in the database
    Medium.where.not(current_filename: nil).each do |medium|
      return false if medium.current_filename.downcase == filename.downcase
    end
    
    true # Filename is unique in database
  end
  
  # Helper method to check if a filename conflicts with OS files (for validation)
  def self.check_os_filename_conflicts(filename)
    require_relative '../../lib/constants'
    conflicts = []
    
    [Constants::UNSORTED_STORAGE, Constants::DAILY_STORAGE, Constants::EVENTS_STORAGE].each do |storage_base|
      next unless Dir.exist?(storage_base)
      
      Dir.glob(File.join(storage_base, '**', '*')).each do |existing_path|
        next unless File.file?(existing_path)
        
        existing_filename = File.basename(existing_path)
        if existing_filename.downcase == filename.downcase
          conflicts << existing_path
        end
      end
    end
    
    conflicts
  end
  
  # Validate batch operations for OS filename conflicts
  def self.validate_batch_operation_for_conflicts(media_ids, operation_type)
    conflicts = []
    
    Medium.where(id: media_ids).each do |medium|
      current_filename = medium.current_filename
      os_conflicts = check_os_filename_conflicts(current_filename)
      
      if os_conflicts.any?
        conflicts << {
          medium_id: medium.id,
          filename: current_filename,
          os_conflicts: os_conflicts,
          operation: operation_type
        }
      end
    end
    
    conflicts
  end
  
  # Method to fix orphaned media records (files that don't exist where database says they should)
  def self.fix_orphaned_media
    Rails.logger.info "=== FIXING ORPHANED MEDIA RECORDS ==="
    fixed_count = 0
    unfixable_count = 0
    
    missing_files = find_missing_files
    
    missing_files.each do |missing|
      medium = Medium.find(missing[:id])
      Rails.logger.info "Attempting to fix Medium #{medium.id}: #{medium.original_filename}"
      
      # Search for the file using current_filename
      found_files = search_for_file(medium.current_filename)
      
      if found_files.any?
        # Found the file! Update the database path
        new_path = found_files.first
        Rails.logger.info "Found file at: #{new_path}"
        
        # Determine correct storage class based on path
        new_storage_class = if new_path.include?('/unsorted/')
          'unsorted'
        elsif new_path.include?('/daily/')
          'daily'
        elsif new_path.include?('/events/')
          'event'
        else
          'unsorted' # fallback
        end
        
        medium.update!(
          file_path: new_path,
          storage_class: new_storage_class,
          event_id: nil, # Reset event associations since we're fixing orphaned records
          subevent_id: nil
        )
        
        Rails.logger.info "✅ Fixed Medium #{medium.id} - updated path to: #{new_path}"
        fixed_count += 1
      else
        Rails.logger.warn "❌ Could not find file for Medium #{medium.id}: #{medium.original_filename}"
        Rails.logger.warn "❌ This medium record may need manual attention"
        unfixable_count += 1
      end
    end
    
    Rails.logger.info "Fixed #{fixed_count} orphaned media records"
    Rails.logger.info "Could not fix #{unfixable_count} orphaned media records"
    Rails.logger.info "=== END FIXING ORPHANED MEDIA RECORDS ==="
    
    { fixed: fixed_count, unfixable: unfixable_count }
  end

  # Scopes
  scope :by_date, -> { order(:datetime_user, :datetime_intrinsic, :datetime_inferred, :created_at) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(medium_type: type) }
  scope :with_event, -> { where.not(event_id: nil) }
  scope :without_event, -> { where(event_id: nil) }
  scope :by_event, ->(event_id) { where(event_id: event_id) }
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
  
  # Scopes for post-processing status
  scope :post_processing_not_started, -> { where(processing_started_at: nil) }
  scope :post_processing_in_progress, -> { where.not(processing_started_at: nil).where(processing_completed_at: nil) }
  scope :post_processing_completed, -> { where.not(processing_started_at: nil).where.not(processing_completed_at: nil) }
  
  # Find media that need post-processing for a specific batch
  def self.needing_post_processing(batch_id: nil, session_id: nil)
    scope = post_processing_not_started
    scope = scope.where(upload_batch_id: batch_id) if batch_id
    scope = scope.where(upload_session_id: session_id) if session_id
    scope
  end
  
  # Get post-processing statistics for a batch or session
  def self.post_processing_stats(batch_id: nil, session_id: nil)
    scope = all
    scope = scope.where(upload_batch_id: batch_id) if batch_id
    scope = scope.where(upload_session_id: session_id) if session_id
    
    {
      total: scope.count,
      not_started: scope.post_processing_not_started.count,
      in_progress: scope.post_processing_in_progress.count,
      completed: scope.post_processing_completed.count
    }
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

  # Get the effective datetime based on priority system
  def effective_datetime
    datetime_user || datetime_intrinsic || datetime_inferred
  end

  # Check if this medium has a valid datetime for file operations
  def has_valid_datetime?
    effective_datetime.present?
  end

  # Get the source of the effective datetime
  def datetime_source
    return 'user' if datetime_user.present?
    return 'intrinsic' if datetime_intrinsic.present?
    return 'inferred' if datetime_inferred.present?
    'none'
  end

  # Check if effective datetime changed
  def effective_datetime_changed?
    datetime_user_changed? || datetime_intrinsic_changed? || datetime_inferred_changed?
  end

  # Legacy method for backwards compatibility
  def taken_date
    effective_datetime || created_at
  end

  # Get the appropriate storage base path based on storage_class
  def storage_base_path
    require_relative '../../lib/constants'
    case storage_class
    when 'unsorted'
      Constants::UNSORTED_STORAGE
    when 'daily'
      Constants::DAILY_STORAGE
    when 'event'
      Constants::EVENTS_STORAGE
    else
      Constants::UNSORTED_STORAGE
    end
  end

  # Delegate methods to mediable object for convenience
  def title
    mediable&.title
  end

  def description  
    mediable&.description
  end
  
  # Check if file exists
  # Helper method to get the full file path (directory + filename)
  def full_file_path
    return nil unless file_path.present? && current_filename.present?
    File.join(file_path, current_filename)
  end
  
  def file_exists?
    full_file_path.present? && File.exist?(full_file_path)
  end

  # Get location from mediable's intrinsic file info (e.g., EXIF data)
  def location
    return nil unless mediable.present?
    
    case medium_type
    when 'photo'
      # For photos, get location from Photo model's latitude/longitude
      if mediable.respond_to?(:latitude) && mediable.respond_to?(:longitude)
        lat = mediable.latitude
        lon = mediable.longitude
        return [lat, lon] if lat.present? && lon.present?
      end
    when 'audio', 'video'
      # For future audio/video support, could extract from metadata
      # For now, return nil
      nil
    else
      nil
    end
  end

  # Check if location is available
  def has_location?
    location.present?
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
  
  # Check if post-processing has been started (either completed or in progress)
  def post_processing_started?
    processing_started_at.present?
  end
  
  # Check if post-processing is currently in progress
  def post_processing_in_progress?
    processing_started_at.present? && processing_completed_at.nil?
  end
  
  # Check if post-processing has been completed
  def post_processing_completed?
    processing_started_at.present? && processing_completed_at.present?
  end
  
  # Get post-processing status as a string
  def post_processing_status
    return 'not_started' unless processing_started_at.present?
    return 'in_progress' if processing_completed_at.nil?
    return 'completed'
  end
  
  # Get post-processing duration in seconds
  def post_processing_duration
    return nil unless processing_started_at.present? && processing_completed_at.present?
    processing_completed_at - processing_started_at
  end

  # Class method to create medium from uploaded file
  def self.create_from_uploaded_file(uploaded_file, user, medium_type = nil, 
              post_process: false, batch_id: nil, session_id: nil, client_file_path: nil)
    upload_started_at = Time.current
    
    # Determine medium type if not specified
    medium_type ||= determine_medium_type_from_content_type(uploaded_file.content_type)
    
    unless medium_type
      return { error: "Unsupported file type: #{uploaded_file.content_type}" }
    end
    
    # Generate unique file path with timestamp and original filename
    # Try to get file modification time, fall back to current time
    file_datetime = get_file_datetime_for_naming(uploaded_file)
    timestamp = file_datetime.strftime("%Y%m%d_%H%M%S")
    original_filename = uploaded_file.original_filename
    stored_filename = "#{timestamp}-#{original_filename}"
    
    # Ensure global uniqueness by checking for duplicates
    stored_filename = ensure_unique_filename(stored_filename)
    
    # Create upload directory in unsorted storage
    require_relative '../../lib/constants'
    upload_dir = File.join(Constants::UNSORTED_STORAGE, medium_type.pluralize)
    FileUtils.mkdir_p(upload_dir) unless Dir.exist?(upload_dir)
    
    # Full file path for saving
    full_file_path = File.join(upload_dir, stored_filename)
    
    # Save file to disk
    save_uploaded_file_to_path(uploaded_file, full_file_path)
    
    # Calculate MD5 hash
    md5_hash = Digest::MD5.file(full_file_path).hexdigest
    
    # Check for duplicates
    existing_medium = find_by(md5_hash: md5_hash)
    if existing_medium
      File.delete(full_file_path) # Clean up duplicate file
      return { error: "Duplicate file already exists", existing: existing_medium }
    end
    
    upload_completed_at = Time.current
    
    # Create the specific media type record first (with dimensions)
    mediable = create_mediable_record(medium_type, uploaded_file, user, full_file_path)
    return { error: "Failed to create #{medium_type} record" } unless mediable
    
    # Create Medium record with timing information
    medium = new(
      file_path: upload_dir,  # Store only the directory path
      file_size: File.size(full_file_path),
      original_filename: uploaded_file.original_filename,
      current_filename: stored_filename,
      content_type: uploaded_file.content_type,
      md5_hash: md5_hash,
      medium_type: medium_type,
      mediable: mediable,
      uploaded_by: user,
      user: user,
      client_file_path: client_file_path,
      datetime_source_last_modified: extract_file_last_modified(uploaded_file),
      upload_started_at: upload_started_at,
      upload_completed_at: upload_completed_at,
      upload_batch_id: batch_id,
      upload_session_id: session_id,
      storage_class: 'unsorted'  # Default to unsorted storage
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
      File.delete(full_file_path) if File.exist?(full_file_path)
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

  def self.create_mediable_record(medium_type, uploaded_file, user, file_path)
    case medium_type
    when 'photo'
      # Extract dimensions for photos
      width, height = extract_dimensions(file_path, uploaded_file.content_type)
      
      Photo.create(
        title: File.basename(uploaded_file.original_filename, '.*').humanize,
        description: nil,
        width: width,
        height: height
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
        
        # Get intrinsic datetime AFTER EXIF extraction
        datetime_intrinsic = photo.datetime_intrinsic
        Rails.logger.info "Extracted datetime_intrinsic: #{datetime_intrinsic} for #{medium.original_filename}"
        
        # Update Medium with intrinsic datetime or set inferred datetime
        if datetime_intrinsic.present?
          medium.update_columns(datetime_intrinsic: datetime_intrinsic)
          Rails.logger.info "Set datetime_intrinsic: #{datetime_intrinsic} for #{medium.original_filename}"
        else
          # No EXIF datetime - use upload time as inferred
          datetime_inferred = medium.created_at
          medium.update_columns(datetime_inferred: datetime_inferred)
          Rails.logger.info "Set datetime_inferred: #{datetime_inferred} for #{medium.original_filename}"
        end
        
        # Update Medium with location data from Photo
        if photo.latitude.present? && photo.longitude.present?
          medium.update_columns(latitude: photo.latitude, longitude: photo.longitude)
        end
      end
      medium.mediable.generate_thumbnail if medium.mediable&.respond_to?(:generate_thumbnail)
    when 'audio'
      # Extract audio metadata when we add audio support
      datetime_intrinsic = medium.mediable.datetime_intrinsic if medium.mediable&.respond_to?(:datetime_intrinsic)
      
      if datetime_intrinsic.present?
        medium.update_columns(datetime_intrinsic: datetime_intrinsic)
      else
        datetime_inferred = medium.created_at
        medium.update_columns(datetime_inferred: datetime_inferred)
      end
    when 'video'
      # Extract video metadata when we add video support
      datetime_intrinsic = medium.mediable.datetime_intrinsic if medium.mediable&.respond_to?(:datetime_intrinsic)
      
      if datetime_intrinsic.present?
        medium.update_columns(datetime_intrinsic: datetime_intrinsic)
      else
        datetime_inferred = medium.created_at
        medium.update_columns(datetime_inferred: datetime_inferred)
      end
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

  # Override destroy_all to include cleanup
  def self.destroy_all
    # First destroy all associated mediable records (photos, audios, videos)
    all.each do |medium|
      medium.mediable&.destroy
    end
    
    result = super
    cleanup
    # Also destroy orphaned events that have no media
    Event.where.not(id: Medium.select(:event_id).where.not(event_id: nil)).destroy_all
    result
  end

  # Cleanup orphaned files in storage directories
  def self.cleanup
    Rails.logger.info "Starting cleanup of orphaned files in storage"
    
    # Get all file paths from database
    db_file_paths = all.map(&:full_file_path).compact.to_set
    Rails.logger.info "Found #{db_file_paths.size} files in database"
    
    # Get all files in storage directories
    require_relative '../../lib/constants'
    orphaned_files = []
    
    # Check each storage directory
    [Constants::UNSORTED_STORAGE, Constants::DAILY_STORAGE].each do |storage_base|
      next unless Dir.exist?(storage_base)
      
      %w[photos videos audios].each do |medium_type|
        storage_dir = File.join(storage_base, medium_type)
        next unless Dir.exist?(storage_dir)
        
        Dir.glob(File.join(storage_dir, '**', '*')).each do |file_path|
          next unless File.file?(file_path)
          
          unless db_file_paths.include?(file_path)
            orphaned_files << file_path
          end
        end
      end
    end
    
    # Handle events storage separately (different structure)
    if Dir.exist?(Constants::EVENTS_STORAGE)
      Dir.glob(File.join(Constants::EVENTS_STORAGE, '**', '*')).each do |file_path|
        next unless File.file?(file_path)
        
        unless db_file_paths.include?(file_path)
          orphaned_files << file_path
        end
      end
    end
    
    # Clean up orphaned thumbnails and previews
    cleanup_orphaned_thumbnails_and_previews(orphaned_files)
    
    Rails.logger.info "Found #{orphaned_files.size} orphaned files"
    
    # Delete orphaned files
    deleted_count = 0
    errors = []
    
    orphaned_files.each do |file_path|
      begin
        File.delete(file_path)
        deleted_count += 1
        Rails.logger.debug "Deleted orphaned file: #{file_path}"
      rescue => e
        error_msg = "#{file_path}: #{e.message}"
        errors << error_msg
        Rails.logger.error "Failed to delete #{file_path}: #{e.message}"
      end
    end
    
    # Clean up empty directories
    empty_dirs_removed = cleanup_empty_directories
    
    Rails.logger.info "Cleanup completed. Deleted: #{deleted_count} files, Removed: #{empty_dirs_removed} empty directories, Errors: #{errors.length}"
    { deleted_count: deleted_count, empty_dirs_removed: empty_dirs_removed, errors: errors, orphaned_files: orphaned_files }
  end

  # Clean up orphaned thumbnails and previews
  def self.cleanup_orphaned_thumbnails_and_previews(orphaned_files)
    require_relative '../../lib/constants'
    
    Rails.logger.info "=== CLEANING UP ORPHANED THUMBNAILS AND PREVIEWS ==="
    
    # Get all thumbnail and preview paths from database that are in the NEW storage locations
    thumbnail_paths = Photo.where.not(thumbnail_path: nil)
                          .where("thumbnail_path LIKE ?", "#{Constants::THUMBNAILS_STORAGE}%")
                          .pluck(:thumbnail_path).compact.to_set
    preview_paths = Photo.where.not(preview_path: nil)
                        .where("preview_path LIKE ?", "#{Constants::PREVIEWS_STORAGE}%")
                        .pluck(:preview_path).compact.to_set
    
    Rails.logger.info "Found #{thumbnail_paths.size} thumbnails and #{preview_paths.size} previews in database using NEW storage locations"
    
    # Check thumbnail storage (only in NEW location)
    if Dir.exist?(Constants::THUMBNAILS_STORAGE)
      Dir.glob(File.join(Constants::THUMBNAILS_STORAGE, '**', '*')).each do |file_path|
        next unless File.file?(file_path)
        
        unless thumbnail_paths.include?(file_path)
          orphaned_files << file_path
          Rails.logger.debug "Found orphaned thumbnail: #{file_path}"
        end
      end
    end
    
    # Check preview storage (only in NEW location)
    if Dir.exist?(Constants::PREVIEWS_STORAGE)
      Dir.glob(File.join(Constants::PREVIEWS_STORAGE, '**', '*')).each do |file_path|
        next unless File.file?(file_path)
        
        unless preview_paths.include?(file_path)
          orphaned_files << file_path
          Rails.logger.debug "Found orphaned preview: #{file_path}"
        end
      end
    end
    
    Rails.logger.info "Found #{orphaned_files.count { |f| f.include?('thumbs') || f.include?('previews') }} orphaned thumbnail/preview files in NEW storage locations"
    Rails.logger.info "=== END CLEANING UP ORPHANED THUMBNAILS AND PREVIEWS ==="
  end

  # Clean up empty directories in all storage locations
  def self.cleanup_empty_directories
    require_relative '../../lib/constants'
    removed_count = 0
    
    # Check unsorted and daily storage directories
    [Constants::UNSORTED_STORAGE, Constants::DAILY_STORAGE].each do |storage_base|
      next unless Dir.exist?(storage_base)
      
      %w[photos videos audios].each do |medium_type|
        storage_dir = File.join(storage_base, medium_type)
        next unless Dir.exist?(storage_dir)
        
        # Recursively find and remove empty directories
        removed_count += remove_empty_dirs_recursive(storage_dir)
      end
    end
    
    # Handle events storage separately (different structure)
    if Dir.exist?(Constants::EVENTS_STORAGE)
      removed_count += remove_empty_dirs_recursive(Constants::EVENTS_STORAGE)
    end
    
    # Clean up empty thumbnail and preview directories
    if Dir.exist?(Constants::THUMBNAILS_STORAGE)
      removed_count += remove_empty_dirs_recursive(Constants::THUMBNAILS_STORAGE)
    end
    
    if Dir.exist?(Constants::PREVIEWS_STORAGE)
      removed_count += remove_empty_dirs_recursive(Constants::PREVIEWS_STORAGE)
    end
    
    removed_count
  end

  # Recursively remove empty directories
  def self.remove_empty_dirs_recursive(dir_path)
    removed_count = 0
    
    # First, recursively clean subdirectories
    if Dir.exist?(dir_path)
      Dir.entries(dir_path).each do |entry|
        next if entry == '.' || entry == '..'
        
        subdir = File.join(dir_path, entry)
        if Dir.exist?(subdir)
          removed_count += remove_empty_dirs_recursive(subdir)
        end
      end
    end
    
    # Then check if this directory is now empty and remove it
    # But don't remove the base storage directories
    if Dir.exist?(dir_path) && Dir.empty?(dir_path)
      require_relative '../../lib/constants'
      base_storage_dirs = [
        Constants::UNSORTED_STORAGE,
        Constants::DAILY_STORAGE, 
        Constants::EVENTS_STORAGE,
        Constants::THUMBNAILS_STORAGE,
        Constants::PREVIEWS_STORAGE
      ]
      
      # Don't remove base storage directories
      unless base_storage_dirs.include?(dir_path)
        begin
          Dir.rmdir(dir_path)
          removed_count += 1
          Rails.logger.debug "Removed empty directory: #{dir_path}"
        rescue => e
          Rails.logger.debug "Could not remove directory #{dir_path}: #{e.message}"
        end
      end
    end
    
    removed_count
  end

  private

  # Extract last modified time from uploaded file
  # Note: ActionDispatch::Http::UploadedFile doesn't preserve the client's original
  # file modification time. The tempfile will have the current time.
  # For true client file modification time, we'd need to capture it in JavaScript
  # and send it as a separate parameter.
  def self.extract_file_last_modified(uploaded_file)
    # For now, use current time as the source modification time
    # This represents when the file was uploaded/processed
    Time.current
  end

  # Get the appropriate datetime for file naming during import
  def self.get_file_datetime_for_naming(uploaded_file)
    # Try to get the file's modification time from the tempfile
    begin
      if uploaded_file.tempfile && File.exist?(uploaded_file.tempfile.path)
        file_mtime = File.mtime(uploaded_file.tempfile.path)
        # Only use file modification time if it's reasonable (not too old, not in the future)
        if file_mtime > 1.year.ago && file_mtime < 1.day.from_now
          return file_mtime
        end
      end
    rescue => e
      Rails.logger.debug "Could not get file modification time: #{e.message}"
    end
    
    # Fall back to current time
    Time.current
  end

  private

  # Callback to rename file on disk when current_filename changes
  def rename_file_on_disk
    old_filename = current_filename_was
    new_filename = current_filename
    
    return if old_filename == new_filename || old_filename.blank? || new_filename.blank?
    
    old_full_path = File.join(file_path, old_filename)
    new_full_path = File.join(file_path, new_filename)
    
    Rails.logger.info "=== RENAMING FILE ON DISK ==="
    Rails.logger.info "Old path: #{old_full_path}"
    Rails.logger.info "New path: #{new_full_path}"
    
    if File.exist?(old_full_path)
      begin
        FileUtils.mv(old_full_path, new_full_path)
        Rails.logger.info "✅ Successfully renamed file from '#{old_filename}' to '#{new_filename}'"
        
        # Also rename thumbnail and preview files if they exist
        rename_associated_files(old_filename, new_filename)
        
      rescue => e
        Rails.logger.error "❌ Failed to rename file: #{e.message}"
        # Add error to prevent saving the database record
        errors.add(:current_filename, "Failed to rename file on disk: #{e.message}")
        throw(:abort)
      end
    else
      Rails.logger.warn "⚠️ Old file not found at: #{old_full_path}"
      # Don't prevent saving, just log the warning
    end
    
    Rails.logger.info "=== END RENAMING FILE ON DISK ==="
  end

  # Callback to rename file if effective datetime changed significantly
  def rename_file_if_datetime_changed
    # Only rename if the datetime change is significant (more than 1 hour difference)
    old_effective_datetime = effective_datetime_was
    new_effective_datetime = effective_datetime
    
    return unless old_effective_datetime.present? && new_effective_datetime.present?
    return if (old_effective_datetime - new_effective_datetime).abs < 1.hour
    
    Rails.logger.info "=== RENAMING FILE DUE TO DATETIME CHANGE ==="
    Rails.logger.info "Old datetime: #{old_effective_datetime}"
    Rails.logger.info "New datetime: #{new_effective_datetime}"
    
    # Generate new filename using effective datetime
    new_filename = generate_filename_from_effective_datetime
    
    # Check if the new filename would conflict
    if Medium.where(current_filename: new_filename).where.not(id: id).exists?
      Rails.logger.warn "⚠️ Cannot rename file due to conflict: #{new_filename}"
      return
    end
    
    # Rename the file
    old_full_path = full_file_path
    new_full_path = File.join(file_path, new_filename)
    
    if File.exist?(old_full_path)
      begin
        FileUtils.mv(old_full_path, new_full_path)
        update_column(:current_filename, new_filename)
        
        # Also rename associated files
        rename_associated_files(current_filename_was, new_filename)
        
        Rails.logger.info "✅ Successfully renamed file due to datetime change: #{new_filename}"
      rescue => e
        Rails.logger.error "❌ Failed to rename file due to datetime change: #{e.message}"
      end
    end
    
    Rails.logger.info "=== END RENAMING FILE DUE TO DATETIME CHANGE ==="
  end

  # Generate filename using effective datetime
  def generate_filename_from_effective_datetime
    effective_dt = effective_datetime || created_at
    timestamp = effective_dt.strftime("%Y%m%d_%H%M%S")
    
    # Extract descriptive name from current filename
    current_name = current_filename || original_filename
    if current_name.include?('-')
      descriptive_part = current_name.split('-', 2)[1] || File.basename(current_name, '.*')
    else
      descriptive_part = File.basename(current_name, '.*')
    end
    
    extension = File.extname(current_name)
    "#{timestamp}-#{descriptive_part}#{extension}"
  end

  # Rename associated thumbnail and preview files
  def rename_associated_files(old_filename, new_filename)
    return unless medium_type == 'photo' && mediable.present?
    
    old_base = File.basename(old_filename, '.*')
    new_base = File.basename(new_filename, '.*')
    old_ext = File.extname(old_filename)
    
    # Rename thumbnail
    if mediable.thumbnail_path.present? && File.exist?(mediable.thumbnail_path)
      old_thumb_path = mediable.thumbnail_path
      if old_thumb_path.include?(old_base)
        new_thumb_path = old_thumb_path.gsub(old_base, new_base)
        begin
          FileUtils.mv(old_thumb_path, new_thumb_path)
          mediable.update_column(:thumbnail_path, new_thumb_path)
          Rails.logger.info "✅ Renamed thumbnail: #{old_thumb_path} -> #{new_thumb_path}"
        rescue => e
          Rails.logger.error "❌ Failed to rename thumbnail: #{e.message}"
        end
      end
    end
    
    # Rename preview
    if mediable.preview_path.present? && File.exist?(mediable.preview_path)
      old_preview_path = mediable.preview_path
      if old_preview_path.include?(old_base)
        new_preview_path = old_preview_path.gsub(old_base, new_base)
        begin
          FileUtils.mv(old_preview_path, new_preview_path)
          mediable.update_column(:preview_path, new_preview_path)
          Rails.logger.info "✅ Renamed preview: #{old_preview_path} -> #{new_preview_path}"
        rescue => e
          Rails.logger.error "❌ Failed to rename preview: #{e.message}"
        end
      end
    end
  end

end