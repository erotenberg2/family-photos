class FileOrganizationService
  require_relative '../../lib/constants'
  
  class << self
    
    # Move media files to daily storage based on their effective datetime
    def move_to_daily_storage(media_ids)
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
          
          # Generate new file path in daily storage
          new_path = generate_daily_storage_path(medium)
          
          # Create directory if it doesn't exist
          FileUtils.mkdir_p(File.dirname(new_path))
          
          # Move the file
          if File.exist?(medium.file_path)
            FileUtils.mv(medium.file_path, new_path)
            
            # Update the database record
            medium.update!(file_path: new_path, storage_class: 'daily')
            
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
    
    private
    
    # Generate the daily storage path based on effective datetime
    def generate_daily_storage_path(medium)
      date = medium.effective_datetime
      
      # Format: daily/YYYY/MM/DD/filename
      year = date.year.to_s
      month = date.month.to_s.rjust(2, '0')
      day = date.day.to_s.rjust(2, '0')
      
      # Generate new filename with datetime
      timestamp = date.strftime("%Y%m%d_%H%M%S")
      base_name = File.basename(medium.original_filename, '.*')
      extension = File.extname(medium.original_filename)
      new_filename = "#{timestamp}_#{base_name}#{extension}"
      
      File.join(Constants::DAILY_STORAGE, medium.medium_type.pluralize, year, month, day, new_filename)
    end
    
    # Clean up empty directories after moving files
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
end
