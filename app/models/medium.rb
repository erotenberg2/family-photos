class Medium < ApplicationRecord
  include AASM
  include MediumAasm

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
  
  # Validations for generic media attributes
  # TODO: file_path is being deprecated in favor of computed paths
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
        if defined?(Photo) && Photo.respond_to?(:valid_types)
          Photo.valid_types.keys
        else
          %w[image/jpeg image/jpg image/png image/gif image/bmp image/tiff image/heic image/heif image/webp]
        end
      when 'audio'
        if defined?(Audio) && Audio.respond_to?(:valid_types)
          Audio.valid_types.keys
        else
          %w[audio/mpeg audio/mp3 audio/wav audio/aac audio/ogg audio/flac]
        end
      when 'video'
        if defined?(Video) && Video.respond_to?(:valid_types)
          Video.valid_types.keys
        else
          %w[video/mp4 video/mov video/avi video/mkv video/webm]
        end
      else
        []
      end
    },
    message: 'must be a valid format for the medium type'
  }
  
  # Validation for descriptive_name (used in filename)
  validate :descriptive_name_contains_no_illegal_characters
  validate :primary_version_exists

  # Callbacks for file operations
  before_update :rename_file_on_disk, if: :current_filename_changed?
  after_update :rename_file_if_datetime_changed, if: :effective_datetime_changed?
  after_update :regenerate_thumbnails_for_primary, if: :primary_changed?
  after_save :sync_versions_json, if: -> { saved_change_to_versions? || saved_change_to_primary? }
  before_destroy :store_mediable_info
  after_destroy :cleanup_thumbnails_and_previews
  
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
     "datetime_user", "event_id", "file_size", "id", "latitude", "longitude", "md5_hash", "medium_type", "original_filename", 
     "storage_state", "subevent_id", "updated_at", "uploaded_by_id", "user_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["event", "mediable", "subevent", "uploaded_by", "user"]
  end
  
  # Debug method to find missing files
  def self.find_missing_files
    Rails.logger.info "=== SEARCHING FOR MISSING FILES ==="
    missing_files = []
    
    Medium.all.each do |medium|
      if medium.current_filename.present?
        unless File.exist?(medium.full_file_path)
          missing_files << {
            id: medium.id,
            original_filename: medium.original_filename,
            file_path: medium.full_file_path,
            storage_state: medium.aasm.current_state,
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
      Rails.logger.info "  Storage state: #{missing[:storage_state]}"
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
        
        # Paths are now computed from state - just reset associations
        medium.update!(
          event_id: nil, # Reset event associations since we're fixing orphaned records
          subevent_id: nil
        )
        
        Rails.logger.info "✅ Fixed Medium #{medium.id} - reset associations"
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

  # Get the appropriate storage base path based on storage_state
  def storage_base_path
    require_relative '../../lib/constants'
    case aasm.current_state
    when :unsorted
      Constants::UNSORTED_STORAGE
    when :daily
      Constants::DAILY_STORAGE
    when :event_root, :subevent_level1, :subevent_level2
      Constants::EVENTS_STORAGE
    else
      Constants::UNSORTED_STORAGE
    end
  end

  # Delegate methods to mediable object for convenience
  def title
    mediable&.title
  end

  # Description is now stored directly on Medium, not delegated from mediable
  
  # Check if file exists
  # Helper method to get the full file path (directory + filename)
  def full_file_path
    dir = computed_directory_path
    return nil unless dir.present? && current_filename.present?
    full_path = File.join(dir, current_filename)
    Rails.logger.debug "Medium#full_file_path: #{full_path} (state: #{storage_state}, event_id: #{event_id}, subevent_id: #{subevent_id})"
    full_path
  end
  
  def file_exists?
    full_file_path.present? && File.exist?(full_file_path)
  end

  # Get the aux folder path for this medium
  def aux_folder_path
    return nil unless current_filename.present?
    base_name = File.basename(current_filename, File.extname(current_filename))
    File.join(computed_directory_path, "#{base_name}_aux")
  end

  # Get the attachments subfolder path within aux folder
  def attachments_folder_path
    return nil unless aux_folder_path.present?
    File.join(aux_folder_path, 'attachments')
  end

  # Get the versions subfolder path within aux folder
  def versions_folder_path
    return nil unless aux_folder_path.present?
    File.join(aux_folder_path, 'versions')
  end

  # Check if aux folder exists
  def aux_folder_exists?
    aux_folder_path.present? && Dir.exist?(aux_folder_path)
  end

  # Get the old aux folder path (before rename or move)
  def old_aux_folder_path(old_filename: nil)
    old_name = old_filename || current_filename_was
    return nil unless old_name.present?
    base_name = File.basename(old_name, File.extname(old_name))
    File.join(computed_directory_path, "#{base_name}_aux")
  end

  # Compute directory based on state and associations
  def computed_directory_path
    require_relative '../../lib/constants'
    case storage_state.to_s
    when 'unsorted'
      Constants::UNSORTED_STORAGE
    when 'daily'
      return nil unless has_valid_datetime?
      dt = effective_datetime
      File.join(Constants::DAILY_STORAGE,
               dt.year.to_s,
               dt.month.to_s.rjust(2, '0'),
               dt.day.to_s.rjust(2, '0'))
    when 'event_root'
      return nil unless event&.folder_name
      File.join(Constants::EVENTS_STORAGE, event.folder_name)
    when 'subevent_level1', 'subevent_level2'
      return nil unless event&.folder_name && subevent
      event_dir = File.join(Constants::EVENTS_STORAGE, event.folder_name)
      if subevent.parent_subevent_id.present?
        parent = subevent.parent_subevent
        File.join(event_dir, parent.footer_name, subevent.footer_name)
      else
        File.join(event_dir, subevent.footer_name)
      end
    else
      Constants::UNSORTED_STORAGE
    end
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
              post_process: false, batch_id: nil, session_id: nil, client_file_path: nil, client_file_date: nil)
    upload_started_at = Time.current
    
    # Determine medium type if not specified
    medium_type ||= determine_medium_type_from_content_type(uploaded_file.content_type)
    
    unless medium_type
      return { error: "Unsupported file type: #{uploaded_file.content_type}" }
    end
    
    # Generate unique file path with temporary timestamp for now
    # The proper datetime-based filename will be set during post-processing
    temp_timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    original_filename = uploaded_file.original_filename
    stored_filename = "#{temp_timestamp}-#{original_filename}"
    
    # Ensure global uniqueness by checking for duplicates
    stored_filename = ensure_unique_filename(stored_filename)
    
    # Create upload directory in unsorted storage (all media types together)
    require_relative '../../lib/constants'
    upload_dir = Constants::UNSORTED_STORAGE
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
    
    # Create the specific media type record (minimal data for now)
    mediable = create_mediable_record(medium_type, uploaded_file, user, full_file_path)
    return { error: "Failed to create #{medium_type} record" } unless mediable
    
    # Create Medium record with timing information
    medium = new(
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
      datetime_source_last_modified: extract_file_last_modified(uploaded_file, client_file_date),
      upload_started_at: upload_started_at,
      upload_completed_at: upload_completed_at,
      upload_batch_id: batch_id,
      upload_session_id: session_id,
      description: ""  # Initialize to empty string, will be populated during post-processing if metadata available
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
    
    # Check against Audio valid types
    if defined?(Audio) && Audio.respond_to?(:valid_types)
      return 'audio' if Audio.valid_types.key?(content_type)
    end
    
    # Check against Video valid types
    if defined?(Video) && Video.respond_to?(:valid_types)
      return 'video' if Video.valid_types.key?(content_type)
    end
    
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
    
    # Add audio types
    if allowed_types.include?('all') || allowed_types.include?('audio')
      if defined?(Audio) && Audio.respond_to?(:valid_types)
        Audio.valid_types.each do |mime_type, extensions|
          acceptable_types[mime_type] = 'audio'
          extensions.each { |ext| valid_extensions[ext] = 'audio' }
        end
      end
    end
    
    # Add video types
    if allowed_types.include?('all') || allowed_types.include?('video')
      if defined?(Video) && Video.respond_to?(:valid_types)
        Video.valid_types.each do |mime_type, extensions|
          acceptable_types[mime_type] = 'video'
          extensions.each { |ext| valid_extensions[ext] = 'video' }
        end
      end
    end
    
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
      # Extract dimensions for photos (minimal data for now)
      width, height = extract_dimensions(file_path, uploaded_file.content_type)
      
      Photo.create(
        title: File.basename(uploaded_file.original_filename, '.*').humanize,
        description: nil,
        width: width,
        height: height
      )
    when 'audio'
      # Create audio record with minimal data
      Audio.create(
        title: File.basename(uploaded_file.original_filename, '.*').humanize,
        description: nil
      )
    when 'video'
      # Extract dimensions for videos (minimal data for now)
      width, height = extract_dimensions(file_path, uploaded_file.content_type)
      
      Video.create(
        title: File.basename(uploaded_file.original_filename, '.*').humanize,
        description: nil,
        width: width,
        height: height
      )
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
        
        # Update Medium with intrinsic datetime if present
        if datetime_intrinsic.present?
          medium.update_columns(datetime_intrinsic: datetime_intrinsic)
          Rails.logger.info "Set datetime_intrinsic: #{datetime_intrinsic} for #{medium.original_filename}"
          
          # Rename file to use proper datetime-based filename
          rename_file_to_datetime_based_name(medium, datetime_intrinsic)
        end
        
        # ALWAYS set datetime_inferred as a fallback, regardless of whether intrinsic exists
        # This ensures we have at least one datetime for sorting/organization
        datetime_inferred = medium.datetime_source_last_modified || get_file_mtime_for_inferred_datetime(medium.full_file_path) || medium.created_at
        medium.update_columns(datetime_inferred: datetime_inferred)
        Rails.logger.info "Set datetime_inferred: #{datetime_inferred} for #{medium.original_filename}"
        
        # Still generate thumbnail and preview even without EXIF datetime
        medium.mediable.generate_thumbnail if medium.mediable&.respond_to?(:generate_thumbnail)
        medium.mediable.generate_preview if medium.mediable&.respond_to?(:generate_preview)
        
        # Update Medium with location data from Photo
        if photo.latitude.present? && photo.longitude.present?
          medium.update_columns(latitude: photo.latitude, longitude: photo.longitude)
        end
        
        # Extract and set description from photo metadata
        description = photo.extract_description_from_metadata if photo.respond_to?(:extract_description_from_metadata)
        medium.update_columns(description: description || "")
        
        # Generate thumbnail and preview after EXIF processing
        medium.mediable.generate_thumbnail if medium.mediable&.respond_to?(:generate_thumbnail)
        medium.mediable.generate_preview if medium.mediable&.respond_to?(:generate_preview)
      else
        # If no mediable record, still try to generate thumbnail/preview
        medium.mediable.generate_thumbnail if medium.mediable&.respond_to?(:generate_thumbnail)
        medium.mediable.generate_preview if medium.mediable&.respond_to?(:generate_preview)
      end
    when 'audio'
      # Extract audio metadata
      if medium.mediable&.respond_to?(:extract_metadata_from_ffprobe, true)
        audio = medium.mediable
        audio.send(:extract_metadata_from_ffprobe)
        # Use update_columns to bypass callbacks and avoid infinite loop
        audio.update_columns(
          title: audio.title,
          artist: audio.artist,
          album: audio.album,
          genre: audio.genre,
          duration: audio.duration,
          bitrate: audio.bitrate,
          year: audio.year,
          track: audio.track,
          comment: audio.comment,
          album_artist: audio.album_artist,
          composer: audio.composer,
          disc_number: audio.disc_number,
          bpm: audio.bpm,
          compilation: audio.compilation,
          publisher: audio.publisher,
          copyright: audio.copyright,
          isrc: audio.isrc,
          metadata: audio.metadata
        )
      end
      
      # Extract and set description from audio metadata
      description = audio.extract_description_from_metadata if audio.respond_to?(:extract_description_from_metadata)
      medium.update_columns(description: description || "")
      
      # Handle datetime
      datetime_intrinsic = medium.mediable.datetime_intrinsic if medium.mediable&.respond_to?(:datetime_intrinsic)
      
      if datetime_intrinsic.present?
        medium.update_columns(datetime_intrinsic: datetime_intrinsic)
        # Rename file to use proper datetime-based filename
        rename_file_to_datetime_based_name(medium, datetime_intrinsic)
      else
        # Use file modification time as inferred
        datetime_inferred = medium.datetime_source_last_modified || get_file_mtime_for_inferred_datetime(medium.full_file_path) || medium.created_at
        medium.update_columns(datetime_inferred: datetime_inferred)
        Rails.logger.info "Set datetime_inferred: #{datetime_inferred} for #{medium.original_filename}"
        # Rename file to use inferred datetime
        rename_file_to_datetime_based_name(medium, datetime_inferred)
      end
    when 'video'
      # Extract and set description from video metadata
      video = medium.mediable
      description = video.extract_description_from_metadata if video&.respond_to?(:extract_description_from_metadata)
      medium.update_columns(description: description || "")
      
      # Extract video metadata when we add video support
      datetime_intrinsic = medium.mediable.datetime_intrinsic if medium.mediable&.respond_to?(:datetime_intrinsic)
      
      if datetime_intrinsic.present?
        medium.update_columns(datetime_intrinsic: datetime_intrinsic)
        # Rename file to use proper datetime-based filename
        rename_file_to_datetime_based_name(medium, datetime_intrinsic)
      else
        # Use file modification time as inferred
        datetime_inferred = medium.datetime_source_last_modified || get_file_mtime_for_inferred_datetime(medium.full_file_path) || medium.created_at
        medium.update_columns(datetime_inferred: datetime_inferred)
        Rails.logger.info "Set datetime_inferred: #{datetime_inferred} for #{medium.original_filename}"
        # Rename file to use inferred datetime
        rename_file_to_datetime_based_name(medium, datetime_inferred)
      end
      
      # Generate video thumbnail and preview
      medium.mediable.generate_thumbnail if medium.mediable&.respond_to?(:generate_thumbnail)
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
    
    # Check each storage directory (all media types together now)
    [Constants::UNSORTED_STORAGE, Constants::DAILY_STORAGE].each do |storage_base|
      next unless Dir.exist?(storage_base)
      
      Dir.glob(File.join(storage_base, '**', '*')).each do |file_path|
        next unless File.file?(file_path)
        
        unless db_file_paths.include?(file_path)
          orphaned_files << file_path
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
    # Include both Photo and Video models
    thumbnail_paths = Photo.where.not(thumbnail_path: nil)
                          .where("thumbnail_path LIKE ?", "#{Constants::THUMBNAILS_STORAGE}%")
                          .pluck(:thumbnail_path).compact.to_set
    preview_paths = Photo.where.not(preview_path: nil)
                        .where("preview_path LIKE ?", "#{Constants::PREVIEWS_STORAGE}%")
                        .pluck(:preview_path).compact.to_set
    
    # Add Video thumbnails and previews if Video is defined
    if defined?(Video)
      thumbnail_paths.merge(Video.where.not(thumbnail_path: nil)
                                .where("thumbnail_path LIKE ?", "#{Constants::THUMBNAILS_STORAGE}%")
                                .pluck(:thumbnail_path).compact)
      preview_paths.merge(Video.where.not(preview_path: nil)
                              .where("preview_path LIKE ?", "#{Constants::PREVIEWS_STORAGE}%")
                              .pluck(:preview_path).compact)
    end
    
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

  def analyze_transition(event_name)
    # Convert to symbol if it's a string
    event_name_sym = event_name.is_a?(Symbol) ? event_name : event_name.to_sym
    
    Rails.logger.info "🔍 [analyze_transition] Medium #{id}: Analyzing transition '#{event_name_sym}'"
    Rails.logger.info "   Current state: #{aasm.current_state}"
    Rails.logger.info "   event_id: #{event_id}, subevent_id: #{subevent_id}"
    Rails.logger.info "   @pending_event_id: #{@pending_event_id}, @pending_subevent_id: #{@pending_subevent_id}"
    
    event = self.class.aasm.events.find { |e| e.name == event_name_sym }
    unless event
      Rails.logger.warn "   ❌ Event '#{event_name_sym}' not found"
      return { allowed_transition: false }
    end
    
    current = aasm.current_state
    transition = event.transitions.find { |t| 
      t.from == current || 
      (t.from.is_a?(Array) && t.from.include?(current))
    }
    unless transition
      Rails.logger.warn "   ❌ No transition found from state '#{current}'"
      return { allowed_transition: false }
    end
    
    Rails.logger.info "   ✅ Found transition: #{current} -> #{transition.to}"
    
    # Get guards and test each one
    guards = Array(transition.options[:guard])
    Rails.logger.info "   Guards to check: #{guards.inspect}"
    
    guard_results = {}
    all_guards_passed = true
    guard_failure_reason = nil
    
    guards.each do |guard|
      if guard.is_a?(Proc)
        Rails.logger.info "   🔐 Checking guard: Proc"
        result = instance_exec(&guard)
        guard_results[:"proc_#{guards.index(guard)}"] = result
        Rails.logger.info "   🔐 Proc guard result: #{result}"
        unless result
          all_guards_passed = false
        end
      else
        Rails.logger.info "   🔐 Calling guard method: #{guard}"
        result = send(guard)
        guard_results[guard] = result
        Rails.logger.info "   🔐 Guard #{guard} result: #{result ? '✅ PASSED' : '❌ FAILED'}"
        if @guard_failure_reason.present?
          Rails.logger.info "   🔐 Guard failure reason: #{@guard_failure_reason}"
        end
        unless result
          all_guards_passed = false
          # Capture guard failure reason if available
          guard_failure_reason ||= @guard_failure_reason if @guard_failure_reason.present?
        end
      end
    end
    
    final_result = {
      allowed_transition: all_guards_passed, 
      guard_results: guard_results.to_a,
      target_state: transition.to,  # Add the target state
      guard_failure_reason: guard_failure_reason
    }
    
    Rails.logger.info "   🎯 Final result: #{all_guards_passed ? '✅ ALLOWED' : '❌ BLOCKED'}"
    if guard_failure_reason
      Rails.logger.info "   🎯 Failure reason: #{guard_failure_reason}"
    end
    
    final_result
  end

  # Version Management Methods
  
  # Get all versions for this medium
  def version_list
    versions || []
  end
  
  # Add a new version to this medium
  # Called by mediable types when they create a modified version
  # @param original_file_path [String] Path to the temporary modified file
  # @param description [String] Description of what makes this version different (branch label)
  # @param options [Hash] Additional options, including :parent (version filename to fork from)
  # @return [Boolean] Success or failure
  def add_version(original_file_path, description, options = {})
    Rails.logger.info "=== add_version called ==="
    Rails.logger.info "  original_file_path: #{original_file_path}"
    Rails.logger.info "  description: #{description}"
    Rails.logger.info "  current_filename: #{current_filename}"
    
    unless original_file_path.present? && File.exist?(original_file_path)
      Rails.logger.error "❌ add_version: original_file_path is missing or file doesn't exist"
      Rails.logger.error "   original_file_path.present?: #{original_file_path.present?}"
      Rails.logger.error "   File.exist?: #{File.exist?(original_file_path) if original_file_path.present?}"
      return false
    end
    
    unless description.present?
      Rails.logger.error "❌ add_version: description is missing"
      return false
    end
    
    parent_version = options[:parent] # Can be nil for root versions
    Rails.logger.info "  parent_version: #{parent_version || 'nil (root)'}"
    
    # Ensure aux folder exists first
    aux_folder = aux_folder_path
    Rails.logger.info "  aux_folder_path: #{aux_folder || 'nil'}"
    unless aux_folder.present?
      Rails.logger.error "❌ Cannot add version: aux_folder_path is nil (current_filename: #{current_filename})"
      return false
    end
    
    # Create aux folder if it doesn't exist
    unless Dir.exist?(aux_folder)
      Rails.logger.info "Creating aux folder: #{aux_folder}"
      FileUtils.mkdir_p(aux_folder)
    end
    
    versions_folder = versions_folder_path
    unless versions_folder.present?
      Rails.logger.error "Cannot add version: versions_folder_path is nil"
      return false
    end
    
    # Create versions folder if it doesn't exist (this will also create aux folder if needed)
    unless Dir.exist?(versions_folder)
      Rails.logger.info "Creating versions folder: #{versions_folder}"
      FileUtils.mkdir_p(versions_folder)
    end
    
    # Generate unique version filename
    # Always use the main file's extension, not the uploaded file's extension
    original_ext = File.extname(current_filename)
    base_version_list = version_list
    version_number = base_version_list.length + 1
    version_filename = nil
    version_path = nil
    
    # Generate candidate filename and ensure uniqueness
    loop do
      candidate_filename = "v#{version_number}_#{description.parameterize}#{original_ext}"
      candidate_path = File.join(versions_folder, candidate_filename)
      
      # Check if this filename is already used in the versions list
      filename_exists_in_list = base_version_list.any? { |v| v['filename'] == candidate_filename }
      
      # Check if file already exists on disk
      file_exists_on_disk = File.exist?(candidate_path)
      
      # If both checks pass, this filename is unique - use it
      unless filename_exists_in_list || file_exists_on_disk
        version_filename = candidate_filename
        version_path = candidate_path
        break  # Found a unique filename
      end
      
      # Conflict detected, increment version number and try again
      Rails.logger.warn "Version filename conflict: #{candidate_filename}, trying next number..."
      version_number += 1
      
      # Safety limit to prevent infinite loops
      if version_number > base_version_list.length + 100
        Rails.logger.error "Could not generate unique version filename after 100 attempts"
        return false
      end
    end
    
    Rails.logger.info "Generated unique version filename: #{version_filename}"
    
    # Move the original file to versions
    begin
      Rails.logger.info "Moving file to versions: #{original_file_path} -> #{version_path}"
      FileUtils.mv(original_file_path, version_path)
      Rails.logger.info "✅ File moved successfully"
      
      # Add version entry to database with parent field
      now = Time.current.iso8601
      version_entry = {
        'filename' => version_filename,
        'description' => description,
        'parent' => parent_version, # nil for root versions, or filename of parent version
        'created_at' => now,
        'modified_at' => now
      }
      
      current_versions = version_list
      current_versions << version_entry
      
      Rails.logger.info "Updating database with #{current_versions.length} version(s)"
      # Update database and sync versions.json
      update!(versions: current_versions)
      
      Rails.logger.info "✅ Added version: #{version_filename} - #{description} (parent: #{parent_version || 'root'})"
      true
    rescue => e
      Rails.logger.error "❌ Failed to add version: #{e.message}"
      Rails.logger.error "   Error class: #{e.class}"
      Rails.logger.error "   Backtrace: #{e.backtrace.first(5).join("\n   ")}"
      false
    end
  end
  
  # Get the path to a specific version file
  def version_file_path(version_filename)
    return nil unless version_filename.present?
    File.join(versions_folder_path, version_filename)
  end
  
  # Check if a version file exists
  def version_exists?(version_filename)
    path = version_file_path(version_filename)
    path.present? && File.exist?(path)
  end

  # Get the file path for the primary version (or main file if primary is null)
  def primary_file_path
    primary_value = read_attribute(:primary)
    if primary_value.present?
      # Use the primary version file
      version_file_path(primary_value)
    else
      # Use the main/root file
      full_file_path
    end
  end

  # Check if primary file exists
  def primary_file_exists?
    primary_file_path.present? && File.exist?(primary_file_path)
  end

  # Get base filename for thumbnail/preview paths (always based on main file, not version)
  def thumbnail_base_filename
    return nil unless current_filename.present?
    File.basename(current_filename, File.extname(current_filename))
  end

  # Get children versions (versions that have this version as parent)
  def version_children(parent_filename)
    version_list.select { |v| v['parent'] == parent_filename }
  end

  # Get the source file path for thumbnail/preview generation (uses primary if set)
  def source_file_path_for_thumbnails
    primary_file_path || full_file_path
  end


  private

  # Validation: ensure primary references an existing version if set
  def primary_version_exists
    # Only validate if primary attribute exists and has a value
    return unless has_attribute?(:primary)
    primary_value = read_attribute(:primary)
    return unless primary_value.present?
    
    unless version_list.any? { |v| v['filename'] == primary_value }
      errors.add(:primary, "must reference an existing version")
    end
  end

  # Sync versions.json file in the versions folder
  def sync_versions_json
    versions_folder = versions_folder_path
    return unless versions_folder.present?
    
    # Create versions folder if it doesn't exist
    FileUtils.mkdir_p(versions_folder) unless Dir.exist?(versions_folder)
    
    json_file_path = File.join(versions_folder, 'versions.json')
    
    begin
      # Build JSON structure with primary and versions
      json_data = {
        'primary' => read_attribute(:primary),
        'versions' => version_list
      }
      
      # Write pretty-printed JSON
      File.write(json_file_path, JSON.pretty_generate(json_data))
      Rails.logger.info "Synced versions.json to: #{json_file_path}"
    rescue => e
      Rails.logger.error "Failed to sync versions.json: #{e.message}"
    end
  end

  # Regenerate thumbnails and previews when primary changes
  def regenerate_thumbnails_for_primary
    return unless primary_file_exists?
    
    # Delete old thumbnails/previews (these are based on main filename)
    cleanup_thumbnails_and_previews
    
    # Regenerate from primary file
    # TODO: Photo/Video models need to be updated to check medium.primary_file_path
    # when generating thumbnails. For now, this will trigger regeneration.
    case medium_type
    when 'photo'
      if mediable.present?
        # Force regeneration - Photo model will need to use primary_file_path
        mediable.generate_thumbnail
      end
    when 'video'
      if mediable.present?
        # Force regeneration - Video model will need to use primary_file_path
        mediable.generate_thumbnail
      end
    end
    
    Rails.logger.info "Regenerated thumbnails/previews for primary: #{read_attribute(:primary) || 'root'}"
  end

  # Extract last modified time from uploaded file
  # Now we can capture it from JavaScript using the File API's lastModified property
  def self.extract_file_last_modified(uploaded_file, client_file_date = nil)
    Rails.logger.info "=== EXTRACT FILE LAST MODIFIED DEBUG ==="
    Rails.logger.info "client_file_date value: #{client_file_date.inspect} (#{client_file_date.class})"
    
    # First, try the client-provided lastModified date from JavaScript
    if client_file_date.present?
      begin
        # Convert to integer first (FormData sends as string), then milliseconds to Time object
        timestamp_ms = client_file_date.to_i
        Rails.logger.info "Converted to integer: #{timestamp_ms}"
        client_date = Time.at(timestamp_ms / 1000.0)
        Rails.logger.info "Converted to Time: #{client_date}"
        
        # Allow dates from 1970 (Unix epoch) to 1 day in the future
        # This is much more permissive - files could be from any time in history
        min_date = Time.at(0)  # Unix epoch: 1970-01-01
        max_date = 1.day.from_now
        Rails.logger.info "Checking if #{client_date} is between #{min_date} and #{max_date}"
        
        # Only use if it's reasonable (not before Unix epoch, not too far in future)
        if client_date >= min_date && client_date < max_date
          Rails.logger.info "✅ USING client-provided lastModified: #{client_date}"
          return client_date
        else
          Rails.logger.info "❌ REJECTED client-provided date (out of range)"
        end
      rescue => e
        Rails.logger.error "❌ Could not convert client_file_date: #{e.message}"
      end
    else
      Rails.logger.info "No client_file_date provided"
    end
    
    # Fallback: Try to get the file's modification time from the tempfile
    # While browsers don't transfer lastModified automatically, the OS might preserve it
    begin
      if uploaded_file.tempfile && File.exist?(uploaded_file.tempfile.path)
        file_mtime = File.mtime(uploaded_file.tempfile.path)
        Rails.logger.info "Tempfile mtime: #{file_mtime}"
        # Only use file modification time if it's reasonable (not before Unix epoch, not too far in future)
        min_date = Time.at(0)  # Unix epoch: 1970-01-01
        max_date = 1.day.from_now
        if file_mtime >= min_date && file_mtime < max_date
          Rails.logger.info "✅ USING tempfile mtime: #{file_mtime}"
          return file_mtime
        else
          Rails.logger.info "❌ REJECTED tempfile mtime (out of range)"
        end
      else
        Rails.logger.info "No tempfile or tempfile doesn't exist"
      end
    rescue => e
      Rails.logger.error "Could not get file modification time: #{e.message}"
    end
    
    # Final fallback: current time
    Rails.logger.info "⚠️ USING FINAL FALLBACK: current time #{Time.current}"
    Rails.logger.info "=== END EXTRACT FILE LAST MODIFIED DEBUG ==="
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

  # Get file modification time from a saved file path for use as datetime_inferred
  def self.get_file_mtime_for_inferred_datetime(file_path)
    return nil unless file_path && File.exist?(file_path)
    
    begin
      file_mtime = File.mtime(file_path)
      # Only use file modification time if it's reasonable (not too old, not too far in future)
      if file_mtime > 10.years.ago && file_mtime < 1.day.from_now
        return file_mtime
      end
    rescue => e
      Rails.logger.debug "Could not get file modification time from #{file_path}: #{e.message}"
    end
    
    nil
  end

  # Rename file to use proper datetime-based filename during post-processing
  def self.rename_file_to_datetime_based_name(medium, datetime)
    Rails.logger.info "Starting file rename for medium #{medium.id}: current_filename=#{medium.current_filename}, original_filename=#{medium.original_filename}"
    
    # Generate new filename using proper datetime
    timestamp = datetime.strftime("%Y%m%d_%H%M%S")
    original_filename = medium.original_filename
    new_filename = "#{timestamp}-#{original_filename}"
    
    Rails.logger.info "Generated new filename: #{new_filename}"
    
    # Check if the new filename would conflict with existing files
    if Medium.where(current_filename: new_filename).where.not(id: medium.id).exists?
      Rails.logger.warn "Cannot rename file - filename already exists: #{new_filename}"
      return false
    end
    
    # Get current file path
    old_file_path = medium.full_file_path
    return false unless old_file_path && File.exist?(old_file_path)
    
    # Generate new file path
    new_file_path = File.join(File.dirname(old_file_path), new_filename)
    
    begin
      # Rename the file on disk
      FileUtils.mv(old_file_path, new_file_path)
      Rails.logger.info "Renamed file from #{File.basename(old_file_path)} to #{File.basename(new_file_path)}"
      
      # Update the database record
      medium.update_columns(current_filename: new_filename)
      Rails.logger.info "Updated current_filename to: #{new_filename}"
      
      # Verify the update worked
      medium.reload
      Rails.logger.info "After reload - current_filename: #{medium.current_filename}, full_file_path: #{medium.full_file_path}"
      
      # Rename associated thumbnail and preview files if they exist
      if medium.mediable&.respond_to?(:thumbnail_path) && medium.mediable.thumbnail_path
        old_thumb_path = medium.mediable.thumbnail_path
        if File.exist?(old_thumb_path)
          thumb_ext = File.extname(old_thumb_path)
          thumb_base = File.basename(old_thumb_path, thumb_ext)
          new_thumb_base = File.basename(new_filename, File.extname(new_filename))
          new_thumb_path = File.join(File.dirname(old_thumb_path), "#{new_thumb_base}_thumb#{thumb_ext}")
          FileUtils.mv(old_thumb_path, new_thumb_path)
          medium.mediable.update_columns(thumbnail_path: new_thumb_path)
        end
      end
      
      if medium.mediable&.respond_to?(:preview_path) && medium.mediable.preview_path
        old_preview_path = medium.mediable.preview_path
        if File.exist?(old_preview_path)
          preview_ext = File.extname(old_preview_path)
          preview_base = File.basename(old_preview_path, preview_ext)
          new_preview_base = File.basename(new_filename, File.extname(new_filename))
          new_preview_path = File.join(File.dirname(old_preview_path), "#{new_preview_base}_preview#{preview_ext}")
          FileUtils.mv(old_preview_path, new_preview_path)
          medium.mediable.update_columns(preview_path: new_preview_path)
        end
      end
      
      # Rename aux folder if it exists
      old_filename = medium.current_filename_was || (old_file_path ? File.basename(old_file_path) : nil)
      if old_filename && old_filename != new_filename
        dir = File.dirname(new_file_path)
        old_base = File.basename(old_filename, File.extname(old_filename))
        new_base = File.basename(new_filename, File.extname(new_filename))
        old_aux_path = File.join(dir, "#{old_base}_aux")
        new_aux_path = File.join(dir, "#{new_base}_aux")
        
        if Dir.exist?(old_aux_path)
          begin
            FileUtils.mv(old_aux_path, new_aux_path)
            Rails.logger.info "Renamed aux folder from #{old_aux_path} to #{new_aux_path}"
          rescue => e
            Rails.logger.error "Failed to rename aux folder: #{e.message}"
          end
        end
      end
      
      true
    rescue => e
      Rails.logger.error "Failed to rename file: #{e.message}"
      false
    end
  end

  # Validation for descriptive_name (used in filename)
  def descriptive_name_contains_no_illegal_characters
    return unless descriptive_name.present?
    # Illegal characters for macOS and Linux: / (forward slash) and null character (\x00)
    # Also problematic: : (colon) on older macOS HFS+, but we'll allow it for modern systems
    illegal_chars = descriptive_name.scan(/[\/\x00]/)
    if illegal_chars.any?
      chars_display = illegal_chars.uniq.map { |c| c == '/' ? 'forward slash (/)' : 'null character' }.join(', ')
      errors.add(:descriptive_name, "contains illegal characters: #{chars_display}. These characters cannot be used in file names on macOS or Linux.")
    end
  end

  # Callback to rename file on disk when current_filename changes
  def rename_file_on_disk
    old_filename = current_filename_was
    new_filename = current_filename
    
    return if old_filename == new_filename || old_filename.blank? || new_filename.blank?
    
    dir = computed_directory_path
    old_full_path = File.join(dir, old_filename)
    new_full_path = File.join(dir, new_filename)
    
    Rails.logger.info "=== RENAMING FILE ON DISK ==="
    Rails.logger.info "Old path: #{old_full_path}"
    Rails.logger.info "New path: #{new_full_path}"
    
    if File.exist?(old_full_path)
      begin
        FileUtils.mv(old_full_path, new_full_path)
        Rails.logger.info "✅ Successfully renamed file from '#{old_filename}' to '#{new_filename}'"
        
        # Also rename thumbnail and preview files if they exist
        rename_associated_files(old_filename, new_filename)
        
        # Rename aux folder if it exists
        rename_aux_folder(old_filename, new_filename, dir)
        
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
    dir = computed_directory_path
    old_full_path = full_file_path
    new_full_path = File.join(dir, new_filename)
    
    if File.exist?(old_full_path)
      begin
        FileUtils.mv(old_full_path, new_full_path)
        update_column(:current_filename, new_filename)
        
        # Also rename associated files
        rename_associated_files(current_filename_was, new_filename)
        
        # Rename aux folder if it exists
        rename_aux_folder(current_filename_was, new_filename, dir)
        
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

  # Rename aux folder when filename changes
  def rename_aux_folder(old_filename, new_filename, dir)
    old_base = File.basename(old_filename, File.extname(old_filename))
    new_base = File.basename(new_filename, File.extname(new_filename))
    old_aux_path = File.join(dir, "#{old_base}_aux")
    new_aux_path = File.join(dir, "#{new_base}_aux")
    
    # If no aux folder exists, that's fine
    unless Dir.exist?(old_aux_path)
      Rails.logger.debug "No aux folder to rename: #{old_aux_path}"
      return
    end
    
    begin
      FileUtils.mv(old_aux_path, new_aux_path)
      Rails.logger.info "✅ Renamed aux folder: #{old_aux_path} -> #{new_aux_path}"
    rescue => e
      Rails.logger.error "❌ Failed to rename aux folder: #{e.message}"
    end
  end

  # Store mediable info before destroy for cleanup
  def store_mediable_info
    @stored_mediable_id = mediable_id
    @stored_mediable_type = mediable_type
    @stored_aux_folder_path = aux_folder_path
  end

  # Cleanup thumbnails and previews when medium is destroyed
  def cleanup_thumbnails_and_previews
    return unless @stored_mediable_type.present?
    
    # Handle Photo
    if @stored_mediable_type == 'Photo' && defined?(Photo)
      if @stored_mediable_id.present?
        photo = Photo.find_by(id: @stored_mediable_id)
        if photo
          [photo.thumbnail_path, photo.preview_path].compact.each do |path|
            if path.present? && File.exist?(path)
              begin
                File.delete(path)
                Rails.logger.info "Deleted thumbnail/preview: #{path}"
              rescue => e
                Rails.logger.error "Failed to delete thumbnail/preview #{path}: #{e.message}"
              end
            end
          end
        end
      end
    end
    
    # Handle Video
    if @stored_mediable_type == 'Video' && defined?(Video)
      if @stored_mediable_id.present?
        video = Video.find_by(id: @stored_mediable_id)
        if video
          [video.thumbnail_path, video.preview_path].compact.each do |path|
            if path.present? && File.exist?(path)
              begin
                File.delete(path)
                Rails.logger.info "Deleted thumbnail/preview: #{path}"
              rescue => e
                Rails.logger.error "Failed to delete thumbnail/preview #{path}: #{e.message}"
              end
            end
          end
        end
      end
    end
    
    # Cleanup aux folder if it exists
    if @stored_aux_folder_path.present? && Dir.exist?(@stored_aux_folder_path)
      begin
        FileUtils.rm_rf(@stored_aux_folder_path)
        Rails.logger.info "Deleted aux folder: #{@stored_aux_folder_path}"
      rescue => e
        Rails.logger.error "Failed to delete aux folder #{@stored_aux_folder_path}: #{e.message}"
      end
    end
  end

end