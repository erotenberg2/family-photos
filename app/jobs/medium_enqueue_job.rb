class MediumEnqueueJob
  include Sidekiq::Job

  def perform(temp_directory, user_id, allowed_media_types = ['all'])
    Rails.logger.info "=== MEDIUM ENQUEUE JOB START ==="
    Rails.logger.info "Job started with temp_directory: #{temp_directory}"
    Rails.logger.info "Job started with user_id: #{user_id}"
    Rails.logger.info "Allowed media types: #{allowed_media_types}"
    Rails.logger.info "Temp directory exists: #{Dir.exist?(temp_directory)}"
    
    user = User.find(user_id)
    Rails.logger.info "Found user: #{user.email}"
    
    begin
      if Dir.exist?(temp_directory)
        Rails.logger.info "Listing temp directory contents:"
        Dir.glob(File.join(temp_directory, '**', '*')).each do |file|
          Rails.logger.info "  - #{file} (#{File.size(file)} bytes)" if File.file?(file)
        end
        
        # Check if we have file metadata (new approach) or actual files (fallback)
        metadata_file = File.join(temp_directory, 'file_metadata.json')
        Rails.logger.info "Looking for metadata file: #{metadata_file}"
        Rails.logger.info "Metadata file exists: #{File.exist?(metadata_file)}"
        
        if File.exist?(metadata_file)
          Rails.logger.info "Using new approach: Process file metadata"
          process_file_metadata(metadata_file, user_id, allowed_media_types)
        else
          Rails.logger.info "Using fallback: Process actual files in directory"
          process_actual_files(temp_directory, user_id, allowed_media_types)
        end
        
        # Clean up temp directory
        FileUtils.rm_rf(temp_directory)
        Rails.logger.info "Cleaned up temp directory: #{temp_directory}"
        
      else
        Rails.logger.error "Temp directory not found: #{temp_directory}"
      end
      
      Rails.logger.info "=== MEDIUM ENQUEUE JOB COMPLETED ==="
      
    rescue => e
      Rails.logger.error "=== MEDIUM ENQUEUE JOB FAILED ==="
      Rails.logger.error "Error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      
      # Clean up temp directory even on failure
      FileUtils.rm_rf(temp_directory) if Dir.exist?(temp_directory)
      
      raise e
    end
  end

  private

  def process_file_metadata(metadata_file, user_id, allowed_media_types)
    Rails.logger.info "Processing file metadata from: #{metadata_file}"
    
    begin
      files_data = JSON.parse(File.read(metadata_file))
      Rails.logger.info "Found #{files_data.length} files in metadata"
      
      # Filter files by allowed media types using Medium model logic
      filtered_files_data = files_data.select do |file_data|
        # Create a mock uploaded file for filtering
        mock_file = OpenStruct.new(
          content_type: file_data['content_type'],
          original_filename: file_data['original_filename']
        )
        
        filtered_result = Medium.filter_acceptable_files([mock_file], allowed_media_types)
        !filtered_result.empty?
      end
      
      Rails.logger.info "After filtering by media types #{allowed_media_types}: #{filtered_files_data.length} files"
      
      if filtered_files_data.any?
        Rails.logger.info "Enqueueing MediumImportJob with #{filtered_files_data.length} files"
        MediumImportJob.perform_async(filtered_files_data, user_id)
      else
        Rails.logger.info "No acceptable media files found to import"
      end
      
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse metadata JSON: #{e.message}"
      raise e
    end
  end

  def process_actual_files(temp_directory, user_id, allowed_media_types)
    Rails.logger.info "Processing actual files from directory: #{temp_directory}"
    
    acceptable_extensions = get_acceptable_extensions(allowed_media_types)
    Rails.logger.info "Looking for files with extensions: #{acceptable_extensions}"
    
    files_data = []
    
    Dir.glob(File.join(temp_directory, '**', '*')).each do |file_path|
      next unless File.file?(file_path)
      
      file_extension = File.extname(file_path).downcase
      next unless acceptable_extensions.include?(file_extension)
      
      Rails.logger.info "Found acceptable file: #{file_path}"
      
      # Read file data
      file_content = File.read(file_path)
      
      files_data << {
        'original_filename' => File.basename(file_path),
        'content_type' => get_content_type_from_extension(file_extension),
        'tempfile_path' => file_path,
        'size' => File.size(file_path),
        'file_data' => Base64.encode64(file_content)
      }
    end
    
    Rails.logger.info "Found #{files_data.length} acceptable files to process"
    
    if files_data.any?
      Rails.logger.info "Enqueueing MediumImportJob with #{files_data.length} files"
      MediumImportJob.perform_async(files_data, user_id)
    else
      Rails.logger.info "No acceptable media files found to import"
    end
  end

  def get_acceptable_extensions(allowed_media_types)
    extensions = []
    
    if allowed_media_types.include?('all') || allowed_media_types.include?('photo')
      extensions += ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.tif', '.heic', '.heif', '.webp']
    end
    
    if allowed_media_types.include?('all') || allowed_media_types.include?('audio')
      extensions += ['.mp3', '.wav', '.aac', '.ogg', '.flac', '.m4a']
    end
    
    if allowed_media_types.include?('all') || allowed_media_types.include?('video')
      extensions += ['.mp4', '.mov', '.avi', '.mkv', '.webm']
    end
    
    extensions
  end

  def get_content_type_from_extension(extension)
    case extension.downcase
    when '.jpg', '.jpeg' then 'image/jpeg'
    when '.png' then 'image/png'
    when '.gif' then 'image/gif'
    when '.bmp' then 'image/bmp'
    when '.tiff', '.tif' then 'image/tiff'
    when '.heic' then 'image/heic'
    when '.heif' then 'image/heif'
    when '.webp' then 'image/webp'
    when '.mp3' then 'audio/mpeg'
    when '.wav' then 'audio/wav'
    when '.aac' then 'audio/aac'
    when '.ogg' then 'audio/ogg'
    when '.flac' then 'audio/flac'
    when '.m4a' then 'audio/mp4'
    when '.mp4' then 'video/mp4'
    when '.mov' then 'video/mov'
    when '.avi' then 'video/avi'
    when '.mkv' then 'video/mkv'
    when '.webm' then 'video/webm'
    else 'application/octet-stream'
    end
  end
end
