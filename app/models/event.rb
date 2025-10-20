class Event < ApplicationRecord
  belongs_to :created_by, class_name: 'User'
  has_many :media, dependent: :nullify
  has_many :subevents, dependent: :destroy
  
  validates :title, presence: true, uniqueness: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date
  
  # Callbacks for folder management
  after_create :set_initial_folder_path
  after_update :rename_event_folder, if: :saved_change_to_title?
  before_destroy :move_media_back_to_unsorted
  after_destroy :cleanup_event_folder_if_safe
  
  # Debug callback to see if any update is happening
  after_update :debug_event_update
  
  scope :by_date, -> { order(:start_date, :end_date) }
  scope :active, -> { where('end_date >= ?', Date.current) }
  scope :past, -> { where('end_date < ?', Date.current) }
  
  def duration_days
    return 0 unless start_date && end_date
    (end_date - start_date).to_i + 1
  end
  
  def date_range_string
    return "#{start_date.strftime('%Y-%m-%d')}" if start_date == end_date
    "#{start_date.strftime('%Y-%m-%d')} to #{end_date.strftime('%Y-%m-%d')}"
  end
  
  def title_with_date_range
    "#{title} (#{date_range_string})"
  end
  
  def folder_name
    # Use parameterize for the date part but preserve the original case for the title
    date_part = "#{start_date.strftime('%Y-%m-%d')}_to_#{end_date.strftime('%Y-%m-%d')}"
    title_part = title.gsub(/[^a-zA-Z0-9\s-]/, '').strip.gsub(/\s+/, '_')
    "#{date_part}_#{title_part}"
  end
  
  def media_count
    media.count
  end
  
  def subevents_count
    subevents.count
  end
  
  # Update date range based on associated media
  def update_date_range_from_media!
    return if media.empty?
    
    dates = media.pluck(:datetime_user, :datetime_intrinsic, :datetime_inferred, :created_at).flatten.compact
    return if dates.empty?
    
    earliest_date = dates.min.to_date
    latest_date = dates.max.to_date
    
    update!(start_date: earliest_date, end_date: latest_date) if earliest_date != start_date || latest_date != end_date
  end
  
  # Ransackable attributes for ActiveAdmin filtering
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "description", "end_date", "id", "start_date", "title", "updated_at", "created_by_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["created_by", "media", "subevents"]
  end
  
  # Manual method to fix file paths for existing events
  def fix_media_file_paths!
    Rails.logger.info "=== MANUALLY FIXING MEDIA FILE PATHS ==="
    Rails.logger.info "Event: #{title} (ID: #{id})"
    Rails.logger.info "Current folder_path: '#{folder_path}'"
    Rails.logger.info "Expected folder_name: '#{folder_name}'"
    
    # Check if any media file paths need updating
    expected_folder_name = folder_name
    updated_count = 0
    
    media.each do |medium|
      Rails.logger.info "Checking Medium #{medium.id}: #{medium.file_path}"
      
      # Extract the current folder name from the file path
      if medium.file_path
        current_folder_match = medium.file_path.match(%r{/events/([^/]+)/})
        if current_folder_match
          current_folder_name = current_folder_match[1]
          Rails.logger.info "  Current folder in file path: '#{current_folder_name}'"
          Rails.logger.info "  Expected folder: '#{expected_folder_name}'"
          
          if current_folder_name != expected_folder_name
            Rails.logger.info "  ⚠️ Folder names don't match - updating file path"
            new_file_path = medium.file_path.gsub(current_folder_name, expected_folder_name)
            Rails.logger.info "  From: #{medium.file_path}"
            Rails.logger.info "  To: #{new_file_path}"
            medium.update_column(:file_path, new_file_path)
            updated_count += 1
            Rails.logger.info "  ✅ Updated Medium #{medium.id}"
          else
            Rails.logger.info "  ✅ Folder names match - no update needed"
          end
        else
          Rails.logger.info "  ⚠️ Could not extract folder name from file path"
        end
      else
        Rails.logger.info "  ⚠️ Medium #{medium.id} has no file_path"
      end
    end
    
    Rails.logger.info "Updated #{updated_count} media file paths"
    Rails.logger.info "=== END MANUALLY FIXING MEDIA FILE PATHS ==="
  end

  private
  
  def end_date_after_start_date
    return unless start_date && end_date
    errors.add(:end_date, 'must be after start date') if end_date < start_date
  end
  
  def rename_event_folder
    Rails.logger.info "=== EVENT FOLDER RENAME CALLBACK TRIGGERED ==="
    Rails.logger.info "Event ID: #{id}"
    Rails.logger.info "Title changed from: '#{title_before_last_save}' to '#{title}'"
    Rails.logger.info "Start date: #{start_date}, End date: #{end_date}"
    Rails.logger.info "Current folder_path: '#{folder_path}'"
    
    return unless start_date && end_date && folder_path.present?
    
    require_relative '../../lib/constants'
    
    # Use the stored folder_path as the old path
    old_path = File.join(Constants::EVENTS_STORAGE, folder_path)
    new_folder_name = folder_name
    new_path = File.join(Constants::EVENTS_STORAGE, new_folder_name)
    
    Rails.logger.info "Old folder_path: '#{folder_path}'"
    Rails.logger.info "New folder name: '#{new_folder_name}'"
    Rails.logger.info "Old path: #{old_path}"
    Rails.logger.info "New path: #{new_path}"
    Rails.logger.info "Events storage base: #{Constants::EVENTS_STORAGE}"
    Rails.logger.info "Old path exists: #{Dir.exist?(old_path)}"
    Rails.logger.info "Paths are different: #{old_path != new_path}"
    
    # Only rename if the folder exists and the name actually changed
    if Dir.exist?(old_path) && old_path != new_path
      begin
        Rails.logger.info "Attempting to rename folder..."
        FileUtils.mv(old_path, new_path)
        Rails.logger.info "✅ Successfully renamed event folder from '#{folder_path}' to '#{new_folder_name}'"
        
        # Update the folder_path in the database
        update_column(:folder_path, new_folder_name)
        
        # Update file paths for all associated media using the improved logic
        update_media_file_paths_improved(new_folder_name)
      rescue => e
        Rails.logger.error "❌ Failed to rename event folder from '#{folder_path}' to '#{new_folder_name}': #{e.message}"
        Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
      end
    else
      Rails.logger.warn "⚠️ Skipping rename - Old path doesn't exist or paths are the same"
      Rails.logger.warn "Old path exists: #{Dir.exist?(old_path)}"
      Rails.logger.warn "Paths different: #{old_path != new_path}"
    end
    
    Rails.logger.info "=== END EVENT FOLDER RENAME CALLBACK ==="
  end
  
  def update_media_file_paths(old_folder_name, new_folder_name)
    Rails.logger.info "=== UPDATING MEDIA FILE PATHS ==="
    Rails.logger.info "Old folder name: '#{old_folder_name}'"
    Rails.logger.info "New folder name: '#{new_folder_name}'"
    Rails.logger.info "Media count in this event: #{media.count}"
    
    updated_count = 0
    media.each do |medium|
      Rails.logger.info "Checking Medium #{medium.id}: #{medium.file_path}"
      if medium.file_path&.include?(old_folder_name)
        new_file_path = medium.file_path.gsub(old_folder_name, new_folder_name)
        Rails.logger.info "Updating Medium #{medium.id} file path:"
        Rails.logger.info "  From: #{medium.file_path}"
        Rails.logger.info "  To: #{new_file_path}"
        medium.update_column(:file_path, new_file_path)
        updated_count += 1
        Rails.logger.info "✅ Updated file path for Medium #{medium.id}"
      else
        Rails.logger.info "Medium #{medium.id} file path doesn't contain old folder name"
      end
    end
    
    Rails.logger.info "Updated #{updated_count} media file paths"
    Rails.logger.info "=== END UPDATING MEDIA FILE PATHS ==="
  end
  
  def update_media_file_paths_improved(expected_folder_name)
    Rails.logger.info "=== UPDATING MEDIA FILE PATHS (IMPROVED) ==="
    Rails.logger.info "Expected folder name: '#{expected_folder_name}'"
    Rails.logger.info "Media count in this event: #{media.count}"
    
    updated_count = 0
    media.each do |medium|
      Rails.logger.info "Checking Medium #{medium.id}: #{medium.file_path}"
      
      # Extract the current folder name from the file path
      if medium.file_path
        current_folder_match = medium.file_path.match(%r{/events/([^/]+)/})
        if current_folder_match
          current_folder_name = current_folder_match[1]
          Rails.logger.info "  Current folder in file path: '#{current_folder_name}'"
          Rails.logger.info "  Expected folder: '#{expected_folder_name}'"
          
          if current_folder_name != expected_folder_name
            Rails.logger.info "  ⚠️ Folder names don't match - updating file path"
            new_file_path = medium.file_path.gsub(current_folder_name, expected_folder_name)
            Rails.logger.info "  From: #{medium.file_path}"
            Rails.logger.info "  To: #{new_file_path}"
            medium.update_column(:file_path, new_file_path)
            updated_count += 1
            Rails.logger.info "  ✅ Updated Medium #{medium.id}"
          else
            Rails.logger.info "  ✅ Folder names match - no update needed"
          end
        else
          Rails.logger.info "  ⚠️ Could not extract folder name from file path"
        end
      else
        Rails.logger.info "  ⚠️ Medium #{medium.id} has no file_path"
      end
    end
    
    Rails.logger.info "Updated #{updated_count} media file paths"
    Rails.logger.info "=== END UPDATING MEDIA FILE PATHS (IMPROVED) ==="
  end
  
  def debug_event_update
    Rails.logger.info "🔍 DEBUG: Event #{id} was updated"
    Rails.logger.info "🔍 Title changed: #{saved_change_to_title?}"
    Rails.logger.info "🔍 All changes: #{saved_changes.keys}"
    if saved_change_to_title?
      Rails.logger.info "🔍 Title change details: #{saved_change_to_title}"
    end
  end
  
  def set_initial_folder_path
    return unless start_date && end_date && title.present?
    
    Rails.logger.info "=== SETTING INITIAL FOLDER PATH ==="
    Rails.logger.info "Event ID: #{id}"
    Rails.logger.info "Title: '#{title}'"
    Rails.logger.info "Start date: #{start_date}, End date: #{end_date}"
    
    folder_name_value = folder_name
    Rails.logger.info "Generated folder name: '#{folder_name_value}'"
    
    update_column(:folder_path, folder_name_value)
    Rails.logger.info "✅ Set folder_path to: '#{folder_name_value}'"
    Rails.logger.info "=== END SETTING INITIAL FOLDER PATH ==="
  end
  
  def move_media_back_to_unsorted
    Rails.logger.info "=== MOVING MEDIA BACK TO UNSORTED (EVENT DELETION) ==="
    Rails.logger.info "Event: #{title} (ID: #{id})"
    Rails.logger.info "Media count to move: #{media.count}"
    
    # Debug: Check if there are any media records that should be associated
    all_media_with_event = Medium.where(event_id: id)
    Rails.logger.info "DEBUG: Media with event_id=#{id}: #{all_media_with_event.count}"
    all_media_with_event.each do |m|
      Rails.logger.info "DEBUG: Medium #{m.id}: #{m.original_filename} at #{m.file_path}"
    end
    
    # Track success/failure for folder cleanup decision
    @media_move_success = true
    @failed_media_count = 0
    
    return if media.empty?
    
    require_relative '../../lib/constants'
    
    # Move all media back to unsorted storage
    media.each do |medium|
      Rails.logger.info "Moving Medium #{medium.id} (#{medium.original_filename}) back to unsorted"
      Rails.logger.info "  Current file path: #{medium.full_file_path}"
      Rails.logger.info "  Current file exists: #{File.exist?(medium.full_file_path) if medium.full_file_path}"
      
      begin
        if medium.file_path && medium.current_filename && File.exist?(medium.full_file_path)
          # Use the current_filename from the database
          current_filename = medium.current_filename
          
          # Determine storage directory based on medium type
          type_dir = File.join(Constants::UNSORTED_STORAGE, medium.medium_type.pluralize)
          FileUtils.mkdir_p(type_dir) unless Dir.exist?(type_dir)
          
          new_path = File.join(type_dir, current_filename)
          
          # Handle filename conflicts by adding -(1), -(2), etc. (database-based)
          if File.exist?(new_path) || !Medium.is_filename_unique_in_database(current_filename)
            extension = File.extname(current_filename)
            base_name = File.basename(current_filename, extension)
            
            counter = 1
            loop do
              new_filename = "#{base_name}-(#{counter})#{extension}"
              new_path = File.join(type_dir, new_filename)
              
              if Medium.is_filename_unique_in_database(new_filename)
                Rails.logger.info "  ⚠️ Filename conflict resolved: #{current_filename} -> #{new_filename}"
                break
              end
              
              counter += 1
              break if counter > 1000 # Safety limit
            end
          end
          
          Rails.logger.info "  Target directory: #{type_dir}"
          Rails.logger.info "  Target directory exists: #{Dir.exist?(type_dir)}"
          Rails.logger.info "  New file path: #{new_path}"
          Rails.logger.info "  New path already exists: #{File.exist?(new_path)}"
          
          # Move the file
          Rails.logger.info "  Attempting to move file..."
          FileUtils.mv(medium.full_file_path, new_path)
          
          # Verify the move was successful
          if File.exist?(new_path)
            Rails.logger.info "  ✅ File move verified - file exists at new location"
            
            # Update the medium record
            medium.update!(
              file_path: type_dir,  # Store only the directory path
              current_filename: File.basename(new_path),
              storage_class: 'unsorted',
              event_id: nil,
              subevent_id: nil
            )
            
            Rails.logger.info "  ✅ Database updated successfully"
            Rails.logger.info "  ✅ Moved Medium #{medium.id} to: #{new_path}"
          else
            Rails.logger.error "  ❌ FILE MOVE FAILED - File does not exist at new location!"
            Rails.logger.error "  ❌ Original file still exists: #{File.exist?(medium.full_file_path)}"
            Rails.logger.error "  ❌ New file exists: #{File.exist?(new_path)}"
            raise "File move verification failed - file not found at destination"
          end
        else
          Rails.logger.warn "  ⚠️ Medium #{medium.id} file not found at: #{medium.full_file_path}"
          Rails.logger.warn "  ⚠️ File path present: #{medium.file_path.present?}"
          Rails.logger.warn "  ⚠️ Current filename present: #{medium.current_filename.present?}"
          Rails.logger.warn "  ⚠️ File exists: #{File.exist?(medium.full_file_path) if medium.full_file_path}"
          
          # Still update the database record even if file is missing
          medium.update!(
            current_filename: current_filename,
            storage_class: 'unsorted',
            event_id: nil,
            subevent_id: nil
          )
          
          Rails.logger.warn "  ⚠️ Database updated despite missing file"
        end
      rescue => e
        Rails.logger.error "  ❌ Failed to move Medium #{medium.id}: #{e.message}"
        Rails.logger.error "  ❌ Backtrace: #{e.backtrace.first(3).join('\n')}"
        
        # Don't update the database if the file move failed
        Rails.logger.error "  ❌ Database NOT updated due to file move failure"
        
        # Track failure for folder cleanup decision
        @media_move_success = false
        @failed_media_count += 1
      end
    end
    
    Rails.logger.info "=== END MOVING MEDIA BACK TO UNSORTED ==="
    Rails.logger.info "Media move success: #{@media_move_success}"
    Rails.logger.info "Failed media count: #{@failed_media_count}"
  end
  
  def cleanup_event_folder_if_safe
    Rails.logger.info "=== CLEANING UP EVENT FOLDER (SAFE MODE) ==="
    Rails.logger.info "Event: #{title} (ID: #{id})"
    Rails.logger.info "Folder path: '#{folder_path}'"
    Rails.logger.info "Media move success: #{@media_move_success}"
    Rails.logger.info "Failed media count: #{@failed_media_count}"
    
    return unless folder_path.present?
    
    # Only cleanup folder if all media was successfully moved
    if @media_move_success && @failed_media_count == 0
      Rails.logger.info "✅ All media successfully moved - proceeding with folder cleanup"
      cleanup_event_folder
    else
      Rails.logger.warn "⚠️ SKIPPING folder cleanup due to media move failures!"
      Rails.logger.warn "⚠️ Failed media count: #{@failed_media_count}"
      Rails.logger.warn "⚠️ Event folder preserved to prevent data loss"
      Rails.logger.warn "⚠️ Manual cleanup may be required"
    end
    
    Rails.logger.info "=== END CLEANING UP EVENT FOLDER (SAFE MODE) ==="
  end
  
  def cleanup_event_folder
    Rails.logger.info "=== CLEANING UP EVENT FOLDER ==="
    Rails.logger.info "Event: #{title} (ID: #{id})"
    Rails.logger.info "Folder path: '#{folder_path}'"
    
    return unless folder_path.present?
    
    require_relative '../../lib/constants'
    
    event_folder_path = File.join(Constants::EVENTS_STORAGE, folder_path)
    
    if Dir.exist?(event_folder_path)
      begin
        Rails.logger.info "Removing event folder: #{event_folder_path}"
        FileUtils.rm_rf(event_folder_path)
        Rails.logger.info "✅ Successfully removed event folder"
      rescue => e
        Rails.logger.error "❌ Failed to remove event folder: #{e.message}"
      end
    else
      Rails.logger.info "Event folder does not exist: #{event_folder_path}"
    end
    
    Rails.logger.info "=== END CLEANING UP EVENT FOLDER ==="
  end
end
