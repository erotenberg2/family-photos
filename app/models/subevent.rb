class Subevent < ApplicationRecord
  belongs_to :event
  belongs_to :parent_subevent, class_name: 'Subevent', optional: true
  has_many :child_subevents, class_name: 'Subevent', foreign_key: 'parent_subevent_id', dependent: :destroy
  has_many :media, dependent: :nullify
  
  validates :title, presence: true
  validate :depth_within_limit
  validate :no_self_reference
  validate :no_circular_reference
  validate :title_contains_no_illegal_characters
  
  # Callbacks for folder management
  after_create :set_initial_folder_path
  after_update :rename_subevent_folder, if: :saved_change_to_title?
  before_destroy :move_media_back_to_unsorted
  after_destroy :cleanup_subevent_folder_if_safe
  
  scope :top_level, -> { where(parent_subevent: nil) }
  scope :by_title, -> { order(:title) }
  
  def hierarchy_path
    return title if parent_subevent.nil?
    "#{parent_subevent.hierarchy_path} > #{title}"
  end
  
  def footer_name
    # Remove illegal characters: / (path separator) and null character
    # Allow: letters, digits, spaces, hyphens, underscores, and most other characters
    # Replace multiple spaces with single space, then replace spaces with underscores
    title.gsub(/[\/\x00]/, '').strip.gsub(/\s+/, ' ').gsub(/\s/, '_')
  end
  
  def media_count
    media.count
  end
  
  def all_media
    # Get media from this subevent and all child subevents
    media_ids = media.pluck(:id)
    child_subevents.each do |child|
      media_ids += child.all_media.pluck(:id)
    end
    Medium.where(id: media_ids)
  end
  
  def depth
    return 1 if parent_subevent.nil?
    parent_subevent.depth + 1
  end
  
  def max_depth_reached?
    depth >= Constants::EVENT_RECURSION_DEPTH
  end
  
  def can_have_children?
    !max_depth_reached?
  end
  
  def ancestry
    ancestors = []
    current = self
    while current.parent_subevent
      current = current.parent_subevent
      ancestors << current
    end
    ancestors.reverse
  end
  
  private
  
  def depth_within_limit
    return unless parent_subevent
    
    if depth > Constants::EVENT_RECURSION_DEPTH
      errors.add(:parent_subevent, "would exceed maximum depth of #{Constants::EVENT_RECURSION_DEPTH} levels")
    end
  end
  
  def no_self_reference
    if parent_subevent_id && parent_subevent_id == id
      errors.add(:parent_subevent, "cannot be itself")
    end
  end
  
  def no_circular_reference
    return unless parent_subevent_id
    
    # Check if this subevent would create a circular reference
    current = parent_subevent
    while current
      if current.id == id
        errors.add(:parent_subevent, "would create a circular reference")
        break
      end
      current = current.parent_subevent
    end
  end
  
  def title_contains_no_illegal_characters
    return unless title.present?
    # Illegal characters for macOS and Linux: / (forward slash) and null character (\x00)
    # Also problematic: : (colon) on older macOS HFS+, but we'll allow it for modern systems
    illegal_chars = title.scan(/[\/\x00]/)
    if illegal_chars.any?
      chars_display = illegal_chars.uniq.map { |c| c == '/' ? 'forward slash (/)' : 'null character' }.join(', ')
      errors.add(:title, "contains illegal characters: #{chars_display}. These characters cannot be used in folder names on macOS or Linux.")
    end
  end
  
  # Ransackable attributes for ActiveAdmin filtering
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "description", "id", "title", "updated_at", "event_id", "parent_subevent_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["child_subevents", "event", "media", "parent_subevent"]
  end
  
  def rename_subevent_folder
    Rails.logger.info "=== SUBEVENT FOLDER RENAME CALLBACK TRIGGERED ==="
    Rails.logger.info "Subevent ID: #{id}"
    Rails.logger.info "Title changed from: '#{title_before_last_save}' to '#{title}'"
    Rails.logger.info "Current folder_path: '#{folder_path}'"
    
    return unless event.folder_path.present? && folder_path.present?
    
    require_relative '../../lib/constants'
    
    # Use the stored folder_path as the old path
    event_dir = File.join(Constants::EVENTS_STORAGE, event.folder_path)
    old_path = File.join(event_dir, folder_path)
    new_folder_name = footer_name
    new_path = File.join(event_dir, new_folder_name)
    
    Rails.logger.info "Event folder_path: '#{event.folder_path}'"
    Rails.logger.info "Old subevent folder_path: '#{folder_path}'"
    Rails.logger.info "New folder name: '#{new_folder_name}'"
    Rails.logger.info "Old path: #{old_path}"
    Rails.logger.info "New path: #{new_path}"
    Rails.logger.info "Old path exists: #{Dir.exist?(old_path)}"
    Rails.logger.info "Paths are different: #{old_path != new_path}"
    
    # Only rename if the folder exists and the name actually changed
    if Dir.exist?(old_path) && old_path != new_path
      begin
        Rails.logger.info "Attempting to rename subevent folder..."
        FileUtils.mv(old_path, new_path)
        Rails.logger.info "✅ Successfully renamed subevent folder from '#{folder_path}' to '#{new_folder_name}' in event '#{event.title}'"
        
        # Update the folder_path in the database
        update_column(:folder_path, new_folder_name)
        
        # Update file paths for all associated media
        update_media_file_paths(folder_path, new_folder_name)
      rescue => e
        Rails.logger.error "❌ Failed to rename subevent folder from '#{folder_path}' to '#{new_folder_name}': #{e.message}"
        Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
      end
    else
      Rails.logger.warn "⚠️ Skipping subevent rename - Old path doesn't exist or paths are the same"
      Rails.logger.warn "Old path exists: #{Dir.exist?(old_path)}"
      Rails.logger.warn "Paths different: #{old_path != new_path}"
    end
    
    Rails.logger.info "=== END SUBEVENT FOLDER RENAME CALLBACK ==="
  end
  
  def update_media_file_paths(old_folder_name, new_folder_name)
    # Paths are now computed from state - no need to update media
    Rails.logger.info "Subevent folder renamed from '#{old_folder_name}' to '#{new_folder_name}' - paths computed from state"
  end
  
  def set_initial_folder_path
    return unless title.present?
    
    Rails.logger.info "=== SETTING INITIAL SUBEVENT FOLDER PATH ==="
    Rails.logger.info "Subevent ID: #{id}"
    Rails.logger.info "Title: '#{title}'"
    
    folder_name_value = footer_name
    Rails.logger.info "Generated folder name: '#{folder_name_value}'"
    
    update_column(:folder_path, folder_name_value)
    Rails.logger.info "✅ Set subevent folder_path to: '#{folder_name_value}'"
    Rails.logger.info "=== END SETTING INITIAL SUBEVENT FOLDER PATH ==="
  end
  
  def move_media_back_to_unsorted
    Rails.logger.info "=== MOVING MEDIA TO PARENT EVENT (SUBEVENT DELETION) ==="
    Rails.logger.info "Subevent: #{title} (ID: #{id}) in Event: #{event.title}"
    Rails.logger.info "Media count to move: #{media.count}"
    
    # Track success/failure for folder cleanup decision
    @media_move_success = true
    @failed_media_count = 0
    
    return if media.empty?
    
    require_relative '../../lib/constants'
    
    # Move all media to the parent event (not unsorted)
    media.each do |medium|
      Rails.logger.info "Moving Medium #{medium.id} (#{medium.original_filename}) to parent event"
      Rails.logger.info "  Current file path: #{medium.full_file_path}"
      Rails.logger.info "  Current file exists: #{File.exist?(medium.full_file_path) if medium.full_file_path}"
      
      begin
        if medium.current_filename.present? && File.exist?(medium.full_file_path)
          # Use the current_filename from the database
          current_filename = medium.current_filename
          
          # Move to parent event directory (not unsorted) - all media types together
          event_dir = File.join(Constants::EVENTS_STORAGE, event.folder_path)
          FileUtils.mkdir_p(event_dir) unless Dir.exist?(event_dir)
          
          new_path = File.join(event_dir, current_filename)
          
          # Handle filename conflicts by adding -(1), -(2), etc. (database-based)
          if File.exist?(new_path) || !Medium.is_filename_unique_in_database(current_filename)
            extension = File.extname(current_filename)
            base_name = File.basename(current_filename, extension)
            
            counter = 1
            loop do
              new_filename = "#{base_name}-(#{counter})#{extension}"
              new_path = File.join(event_dir, new_filename)
              
              if Medium.is_filename_unique_in_database(new_filename)
                Rails.logger.info "  ⚠️ Filename conflict resolved: #{current_filename} -> #{new_filename}"
                current_filename = new_filename
                break
              end
              
              counter += 1
              break if counter > 1000 # Safety limit
            end
          end
          
          Rails.logger.info "  Target directory: #{event_dir}"
          Rails.logger.info "  Target directory exists: #{Dir.exist?(event_dir)}"
          Rails.logger.info "  New file path: #{new_path}"
          Rails.logger.info "  New path already exists: #{File.exist?(new_path)}"
          
          # Move the file
          Rails.logger.info "  Attempting to move file..."
          FileUtils.mv(medium.full_file_path, new_path)
          
          # Verify the move was successful
          if File.exist?(new_path)
            Rails.logger.info "  ✅ File move verified - file exists at new location"
            
            # Update the medium record - keep in event but remove subevent association
            medium.update!(
              current_filename: File.basename(new_path),
              event_id: event.id,
              subevent_id: nil
            )
            
            Rails.logger.info "  ✅ Database updated successfully"
            Rails.logger.info "  ✅ Moved Medium #{medium.id} to parent event: #{new_path}"
          else
            Rails.logger.error "  ❌ FILE MOVE FAILED - File does not exist at new location!"
            Rails.logger.error "  ❌ Original file still exists: #{File.exist?(medium.full_file_path)}"
            Rails.logger.error "  ❌ New file exists: #{File.exist?(new_path)}"
            raise "File move verification failed - file not found at destination"
          end
        else
          Rails.logger.warn "  ⚠️ Medium #{medium.id} file not found at: #{medium.full_file_path}"
          Rails.logger.warn "  ⚠️ Current filename present: #{medium.current_filename.present?}"
          Rails.logger.warn "  ⚠️ File exists: #{File.exist?(medium.full_file_path) if medium.full_file_path}"
          
          # Still update the database record even if file is missing
          medium.update!(
            current_filename: medium.current_filename,
            event_id: event.id,
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
    
    Rails.logger.info "=== END MOVING MEDIA TO PARENT EVENT ==="
    Rails.logger.info "Media move success: #{@media_move_success}"
    Rails.logger.info "Failed media count: #{@failed_media_count}"
  end
  
  def cleanup_subevent_folder_if_safe
    Rails.logger.info "=== CLEANING UP SUBEVENT FOLDER (SAFE MODE) ==="
    Rails.logger.info "Subevent: #{title} (ID: #{id}) in Event: #{event.title}"
    Rails.logger.info "Folder path: '#{folder_path}'"
    Rails.logger.info "Media move success: #{@media_move_success}"
    Rails.logger.info "Failed media count: #{@failed_media_count}"
    
    return unless folder_path.present?
    
    # Only cleanup folder if all media was successfully moved
    if @media_move_success && @failed_media_count == 0
      Rails.logger.info "✅ All media successfully moved - proceeding with folder cleanup"
      cleanup_subevent_folder
    else
      Rails.logger.warn "⚠️ SKIPPING folder cleanup due to media move failures!"
      Rails.logger.warn "⚠️ Failed media count: #{@failed_media_count}"
      Rails.logger.warn "⚠️ Subevent folder preserved to prevent data loss"
      Rails.logger.warn "⚠️ Manual cleanup may be required"
    end
    
    Rails.logger.info "=== END CLEANING UP SUBEVENT FOLDER (SAFE MODE) ==="
  end
  
  def cleanup_subevent_folder
    Rails.logger.info "=== CLEANING UP SUBEVENT FOLDER ==="
    Rails.logger.info "Subevent: #{title} (ID: #{id}) in Event: #{event.title}"
    Rails.logger.info "Folder path: '#{folder_path}'"
    
    return unless folder_path.present?
    
    require_relative '../../lib/constants'
    
    # Subevent folder is nested within the event folder
    event_dir = File.join(Constants::EVENTS_STORAGE, event.folder_path)
    subevent_folder_path = File.join(event_dir, folder_path)
    
    if Dir.exist?(subevent_folder_path)
      begin
        Rails.logger.info "Removing subevent folder: #{subevent_folder_path}"
        FileUtils.rm_rf(subevent_folder_path)
        Rails.logger.info "✅ Successfully removed subevent folder"
      rescue => e
        Rails.logger.error "❌ Failed to remove subevent folder: #{e.message}"
      end
    else
      Rails.logger.info "Subevent folder does not exist: #{subevent_folder_path}"
    end
    
    Rails.logger.info "=== END CLEANING UP SUBEVENT FOLDER ==="
  end
end
