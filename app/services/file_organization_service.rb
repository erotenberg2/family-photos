class FileOrganizationService
  require_relative '../../lib/constants'
  
  class << self
    
    # Move a single medium to unsorted storage
    def move_single_to_unsorted(medium)
      Rails.logger.info "FileOrganizationService: Moving medium #{medium.id} to unsorted storage"
      
      # All media types go directly in unsorted (no type subdirectory)
      FileUtils.mkdir_p(Constants::UNSORTED_STORAGE) unless Dir.exist?(Constants::UNSORTED_STORAGE)
      
      # Use the current_filename from the database
      current_filename = medium.current_filename
      new_path = File.join(Constants::UNSORTED_STORAGE, current_filename)
      
      # Handle filename conflicts by adding -(1), -(2), etc. (database-based)
      # Check if the file already exists at the destination (excluding the current record)
      destination_file_exists = File.exist?(new_path)
      db_conflict_exists = Medium.where.not(id: medium.id).where("LOWER(current_filename) = ?", current_filename.downcase).exists?
      
      if destination_file_exists || db_conflict_exists
        extension = File.extname(current_filename)
        base_name = File.basename(current_filename, extension)
        
        # Check if filename already has a -(N) suffix
        if base_name =~ /-\((\d+)\)$/
          # Already has a suffix, increment it
          counter = $1.to_i + 1
          base_name = base_name.sub(/-\(\d+\)$/, '')
        else
          # No suffix, start at 1
          counter = 1
        end
        
        loop do
          new_filename = "#{base_name}-(#{counter})#{extension}"
          new_path = File.join(Constants::UNSORTED_STORAGE, new_filename)
          
          destination_exists = File.exist?(new_path)
          db_exists = Medium.where.not(id: medium.id).where("LOWER(current_filename) = ?", new_filename.downcase).exists?
          
          if !destination_exists && !db_exists
            current_filename = new_filename
            Rails.logger.info "  ⚠️ Filename conflict resolved: #{medium.current_filename} -> #{new_filename}"
            break
          end
          
          counter += 1
          break if counter > 1000 # Safety limit
        end
      end
      
      # Move the file if it exists
      if File.exist?(medium.full_file_path)
        # Save the old file path before moving
        old_path = medium.file_path
        
        FileUtils.mv(medium.full_file_path, new_path)
        
        # Update the database record
        medium.update!(file_path: Constants::UNSORTED_STORAGE, current_filename: current_filename, storage_class: 'unsorted')
        
        Rails.logger.info "  ✅ Moved Medium #{medium.id} to unsorted: #{new_path}"
        
        # Clean up empty directories in the source location
        cleanup_empty_source_directories(old_path)
        
        true
      else
        Rails.logger.warn "  ⚠️ File not found: #{medium.full_file_path}"
        # Still update the database record
        medium.update!(file_path: Constants::UNSORTED_STORAGE, current_filename: current_filename, storage_class: 'unsorted')
        false
      end
    rescue => e
      Rails.logger.error "  ❌ Failed to move Medium #{medium.id} to unsorted: #{e.message}"
      false
    end
    
    # Move a single medium to daily storage
    def move_single_to_daily(medium)
      Rails.logger.info "FileOrganizationService: Moving medium #{medium.id} to daily storage"
      
      # Check if medium has valid datetime
      unless medium.has_valid_datetime?
        Rails.logger.error "  ❌ Medium #{medium.id} has no valid datetime"
        return false
      end
      
      # Generate new file path in daily storage
      new_path = generate_daily_storage_path(medium)
      
      # Create directory if it doesn't exist
      FileUtils.mkdir_p(File.dirname(new_path))
      
      # Move the file if it exists
      if File.exist?(medium.full_file_path)
        # Save the old file path before moving
        old_path = medium.file_path
        
        FileUtils.mv(medium.full_file_path, new_path)
        
        # Update the database record
        medium.update!(file_path: File.dirname(new_path), current_filename: File.basename(new_path), storage_class: 'daily')
        
        Rails.logger.info "  ✅ Moved Medium #{medium.id} to daily: #{new_path}"
        
        # Clean up empty directories in the source location
        cleanup_empty_source_directories(old_path)
        
        true
      else
        Rails.logger.warn "  ⚠️ File not found: #{medium.full_file_path}"
        false
      end
    rescue => e
      Rails.logger.error "  ❌ Failed to move Medium #{medium.id} to daily: #{e.message}"
      false
    end
    
    # Move a single medium to event storage
    def move_single_to_event(medium, event_id)
      Rails.logger.info "FileOrganizationService: Moving medium #{medium.id} to event #{event_id}"
      
      event = Event.find(event_id)
      
      # Create event directory (all media types together)
      event_dir = File.join(Constants::EVENTS_STORAGE, event.folder_name)
      FileUtils.mkdir_p(event_dir) unless Dir.exist?(event_dir)
      
      # Use the current_filename from the database
      current_filename = medium.current_filename
      new_path = File.join(event_dir, current_filename)
      
      # Move the file if it exists
      if File.exist?(medium.full_file_path)
        # Save the old file path before moving
        old_path = medium.file_path
        
        if medium.full_file_path == new_path
          # File is already in the correct location, just update the database
          medium.update!(file_path: File.dirname(new_path), current_filename: File.basename(new_path), storage_class: 'event', event_id: event_id)
          Rails.logger.info "  ✅ File already in correct location, updated database"
        else
          # File needs to be moved
          FileUtils.mv(medium.full_file_path, new_path)
          
          # Update the database record
          medium.update!(file_path: File.dirname(new_path), current_filename: File.basename(new_path), storage_class: 'event', event_id: event_id)
          
          Rails.logger.info "  ✅ Moved Medium #{medium.id} to event: #{new_path}"
          
          # Clean up empty directories in the source location
          cleanup_empty_source_directories(old_path)
        end
        
        true
      else
        Rails.logger.warn "  ⚠️ File not found: #{medium.full_file_path}"
        false
      end
    rescue => e
      Rails.logger.error "  ❌ Failed to move Medium #{medium.id} to event: #{e.message}"
      false
    end
    
    # Move a single medium to subevent storage (for level 1 or level 2)
    def move_single_to_subevent(medium, subevent_id)
      Rails.logger.info "FileOrganizationService: Moving medium #{medium.id} to subevent #{subevent_id}"
      
      subevent = Subevent.find(subevent_id)
      event = subevent.event
      
      # Determine the subevent path (handle both level 1 and level 2)
      event_dir = File.join(Constants::EVENTS_STORAGE, event.folder_name)
      
      # Build subevent path based on hierarchy
      if subevent.parent_subevent_id.present?
        # Level 2 subevent - needs parent path
        parent = subevent.parent_subevent
        subevent_dir = File.join(event_dir, parent.footer_name, subevent.footer_name)
      else
        # Level 1 subevent
        subevent_dir = File.join(event_dir, subevent.footer_name)
      end
      
      FileUtils.mkdir_p(subevent_dir) unless Dir.exist?(subevent_dir)
      
      # Use the current_filename from the database (all media types together)
      current_filename = medium.current_filename
      new_path = File.join(subevent_dir, current_filename)
      
      # Move the file if it exists
      if File.exist?(medium.full_file_path)
        # Save the old file path before moving
        old_path = medium.file_path
        
        if medium.full_file_path == new_path
          # File is already in the correct location, just update the database
          medium.update!(file_path: File.dirname(new_path), current_filename: File.basename(new_path), storage_class: 'event', event_id: event.id, subevent_id: subevent_id)
          Rails.logger.info "  ✅ File already in correct location, updated database"
        else
          # File needs to be moved
          FileUtils.mv(medium.full_file_path, new_path)
          
          # Update the database record
          medium.update!(file_path: File.dirname(new_path), current_filename: File.basename(new_path), storage_class: 'event', event_id: event.id, subevent_id: subevent_id)
          
          Rails.logger.info "  ✅ Moved Medium #{medium.id} to subevent: #{new_path}"
          
          # Clean up empty directories in the source location
          cleanup_empty_source_directories(old_path)
        end
        
        true
      else
        Rails.logger.warn "  ⚠️ File not found: #{medium.full_file_path}"
        false
      end
    rescue => e
      Rails.logger.error "  ❌ Failed to move Medium #{medium.id} to subevent: #{e.message}"
      false
    end
    
    # Move media files to daily storage based on their effective datetime
    def move_to_daily_storage(media_ids)
      # Pre-check for OS conflicts before starting the batch
      conflict_check = validate_batch_operation_for_os_conflicts(media_ids, 'daily')
      if conflict_check[:has_conflicts]
        return {
          success_count: 0,
          error_count: media_ids.length,
          errors: conflict_check[:conflicts].map { |c| "OS conflict: #{c[:filename]} already exists at destination" }
        }
      end
      
      results = {
        success_count: 0,
        error_count: 0,
        errors: []
      }
      
      media_ids.each do |media_id|
        begin
          medium = Medium.find(media_id)
          
          # Check if medium has valid datetime
          unless medium.has_valid_datetime?
            results[:errors] << "Medium #{medium.id} (#{medium.original_filename}) has no valid datetime"
            results[:error_count] += 1
            next
          end
          
          # Generate new file path in daily storage (preserve original filename)
          new_path = generate_daily_storage_path(medium)
          
          # Create directory if it doesn't exist
          FileUtils.mkdir_p(File.dirname(new_path))
          
          # Move the file
          if File.exist?(medium.full_file_path)
            FileUtils.mv(medium.full_file_path, new_path)
            
            # Update the database record
            medium.update!(file_path: File.dirname(new_path), current_filename: File.basename(new_path), storage_class: 'daily')
            
            results[:success_count] += 1
            Rails.logger.info "Moved #{medium.original_filename} to daily storage: #{new_path}"
            
            # Clean up empty directories in the source location
            cleanup_empty_source_directories(medium.file_path)
          else
            results[:errors] << "File not found for Medium #{medium.id}: #{medium.file_path}"
            results[:error_count] += 1
          end
          
        rescue => e
          results[:errors] << "Error processing Medium #{media_id}: #{e.message}"
          results[:error_count] += 1
          Rails.logger.error "Error moving Medium #{media_id} to daily storage: #{e.message}"
        end
      end
      
      results
    end
    
    # Validate batch operation for OS conflicts before starting the move
    def validate_batch_operation_for_os_conflicts(media_ids, storage_type, event_id = nil)
      conflicts = []
      
      media_ids.each do |media_id|
        medium = Medium.find(media_id)
        
        case storage_type
        when 'daily'
          target_path = generate_daily_storage_path(medium)
        when 'event'
          event = Event.find(event_id)
          event_dir = File.join(Constants::EVENTS_STORAGE, event.folder_name)
          target_path = File.join(event_dir, medium.current_filename)
        else
          next
        end
        
        if File.exist?(target_path)
          conflicts << {
            medium_id: medium.id,
            filename: medium.current_filename,
            target_path: target_path
          }
        end
      end
      
      {
        has_conflicts: conflicts.any?,
        conflicts: conflicts
      }
    end
    
    # Generate the daily storage path based on effective datetime
    def generate_daily_storage_path(medium)
      date = medium.effective_datetime
      
      # Format: daily/YYYY/MM/DD/filename (all media types together)
      year = date.year.to_s
      month = date.month.to_s.rjust(2, '0')
      day = date.day.to_s.rjust(2, '0')
      
      # Use the current_filename from the database
      current_filename = medium.current_filename
      
      File.join(Constants::DAILY_STORAGE, year, month, day, current_filename)
    end
    
    # Clean up empty directories after moving files (public so it can be called from outside)
    def cleanup_empty_source_directories(old_file_path)
      return unless old_file_path
      
      # Get the directory containing the file
      dir_path = File.dirname(old_file_path)
      
      # Walk up the directory tree and remove empty directories
      while dir_path && dir_path != Constants::UNSORTED_STORAGE && dir_path != Constants::DAILY_STORAGE && dir_path != Constants::EVENTS_STORAGE
        if Dir.exist?(dir_path) && Dir.empty?(dir_path)
          begin
            Dir.rmdir(dir_path)
            Rails.logger.debug "Removed empty directory after file move: #{dir_path}"
            dir_path = File.dirname(dir_path)  # Move up one level
          rescue => e
            Rails.logger.debug "Could not remove directory #{dir_path}: #{e.message}"
            break
          end
        else
          break  # Directory not empty or doesn't exist, stop here
        end
      end
    end
  end
  
  # Move media to event storage
  def self.move_to_event_storage(media_ids, event_id)
    # Pre-check for OS conflicts before starting the batch
    conflict_check = validate_batch_operation_for_os_conflicts(media_ids, 'event', event_id)
    if conflict_check[:has_conflicts]
      return {
        success_count: 0,
        error_count: media_ids.length,
        errors: conflict_check[:conflicts].map { |c| "OS conflict: #{c[:filename]} already exists at destination" }
      }
    end
    
    results = { success_count: 0, error_count: 0, errors: [] }
    
    event = Event.find(event_id)
    media = Medium.where(id: media_ids)
    
    # Create event directory
    event_dir = File.join(Constants::EVENTS_STORAGE, event.folder_name)
    FileUtils.mkdir_p(event_dir) unless Dir.exist?(event_dir)
    
    media.each do |medium|
      begin
        if medium.has_valid_datetime?
          # Use the current_filename from the database (all media types together)
          current_filename = medium.current_filename
          new_path = File.join(event_dir, current_filename)
          
          # Move the file
          if File.exist?(medium.full_file_path)
            if medium.full_file_path == new_path
              # File is already in the correct location, just update the database
              medium.update!(file_path: File.dirname(new_path), current_filename: File.basename(new_path), storage_class: 'event', event_id: event_id)
              results[:success_count] += 1
              Rails.logger.info "File #{medium.original_filename} already in correct location, updated database record"
            else
              # File needs to be moved
              FileUtils.mv(medium.full_file_path, new_path)
              
              # Update the database record
              medium.update!(file_path: File.dirname(new_path), current_filename: File.basename(new_path), storage_class: 'event', event_id: event_id)
              
              results[:success_count] += 1
              Rails.logger.info "Moved #{medium.original_filename} to event storage: #{new_path}"
            end
          else
            results[:errors] << "File not found for Medium #{medium.id}: #{medium.file_path}"
            results[:error_count] += 1
          end
        else
          results[:errors] << "Medium #{medium.original_filename} (ID: #{medium.id}) has no valid datetime for event storage."
          results[:error_count] += 1
        end
      rescue => e
        results[:errors] << "Failed to move #{medium.original_filename}: #{e.message}"
        results[:error_count] += 1
      end
    end
    
    # Clean up empty source directories
    media.each do |medium|
      cleanup_empty_source_directories(medium.file_path_before_last_save) if medium.previous_changes.key?('file_path')
    end
    
    # Update event date range based on new media
    event.update_date_range_from_media!
    
    results
  end
  
  # Move media to subevent storage
  def self.move_to_subevent_storage(media_ids, subevent_id)
    results = { success_count: 0, error_count: 0, errors: [] }
    
    subevent = Subevent.find(subevent_id)
    event = subevent.event
    media = Medium.where(id: media_ids)
    
    # Create subevent directory within event directory
    event_dir = File.join(Constants::EVENTS_STORAGE, event.folder_name)
    subevent_dir = File.join(event_dir, subevent.footer_name)
    FileUtils.mkdir_p(subevent_dir) unless Dir.exist?(subevent_dir)
    
    media.each do |medium|
      begin
        if medium.has_valid_datetime?
          # Generate new filename (YYYYMMDD_HHMMSS_originalfilename.ext) - all media types together
          date = medium.effective_datetime
          timestamp = date.strftime("%Y%m%d_%H%M%S")
          base_name = File.basename(medium.original_filename, '.*')
          extension = File.extname(medium.original_filename)
          new_filename = "#{timestamp}_#{base_name}#{extension}"
          new_path = File.join(subevent_dir, new_filename)
          
          # Move the file
          if File.exist?(medium.file_path)
            if medium.file_path == new_path
              # File is already in the correct location, just update the database
              medium.update!(storage_class: 'event', event_id: event.id, subevent_id: subevent_id)
              results[:success_count] += 1
              Rails.logger.info "File #{medium.original_filename} already in correct location, updated database record"
            else
              # File needs to be moved
              FileUtils.mv(medium.file_path, new_path)
              
              # Update the database record
              medium.update!(file_path: new_path, storage_class: 'event', event_id: event.id, subevent_id: subevent_id)
              
              results[:success_count] += 1
              Rails.logger.info "Moved #{medium.original_filename} to subevent storage: #{new_path}"
            end
          else
            results[:errors] << "File not found for Medium #{medium.id}: #{medium.file_path}"
            results[:error_count] += 1
          end
        else
          results[:errors] << "Medium #{medium.original_filename} (ID: #{medium.id}) has no valid datetime for subevent storage."
          results[:error_count] += 1
        end
      rescue => e
        results[:errors] << "Failed to move #{medium.original_filename}: #{e.message}"
        results[:error_count] += 1
      end
    end
    
    # Clean up empty source directories
    media.each do |medium|
      cleanup_empty_source_directories(medium.file_path_before_last_save) if medium.previous_changes.key?('file_path')
    end
    
    # Update event date range based on new media
    event.update_date_range_from_media!
    
    results
  end
end
