class PhotoEnqueueJob
  include Sidekiq::Job

  def perform(temp_directory, user_id)
    Rails.logger.info "=== PHOTO ENQUEUE JOB START ==="
    Rails.logger.info "Job started with temp_directory: #{temp_directory}"
    Rails.logger.info "Job started with user_id: #{user_id}"
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
          process_file_metadata(metadata_file, user_id)
        else
          Rails.logger.info "Using fallback: Process actual files in directory"
          process_actual_files(temp_directory, user_id)
        end
        
        # Clean up temp directory
        FileUtils.rm_rf(temp_directory)
        Rails.logger.info "Cleaned up temp directory: #{temp_directory}"
        
      else
        Rails.logger.error "Temp directory not found: #{temp_directory}"
      end
      
      Rails.logger.info "=== PHOTO ENQUEUE JOB COMPLETED ==="
      
    rescue => e
      Rails.logger.error "=== PHOTO ENQUEUE JOB FAILED ==="
      Rails.logger.error "Error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      
      # Clean up temp directory even on failure
      FileUtils.rm_rf(temp_directory) if Dir.exist?(temp_directory)
      
      raise e
    end
  end

  private

  def process_file_metadata(metadata_file, user_id)
    Rails.logger.info "=== PROCESS FILE METADATA START ==="
    Rails.logger.info "Processing file metadata from: #{metadata_file}"
    Rails.logger.info "Metadata file size: #{File.size(metadata_file)} bytes"
    
    metadata = JSON.parse(File.read(metadata_file))
    files = metadata['files'] || []
    total_files = metadata['total_files'] || 0
    user_id_from_metadata = metadata['user_id']
    created_at = metadata['created_at']
    
    Rails.logger.info "Parsed metadata:"
    Rails.logger.info "  - files count: #{files.length}"
    Rails.logger.info "  - total_files: #{total_files}"
    Rails.logger.info "  - user_id: #{user_id_from_metadata}"
    Rails.logger.info "  - created_at: #{created_at}"
    Rails.logger.info "  - first 3 files: #{files.first(3).map { |f| f['name'] }}"
    
    # Process files in chunks
    chunk_size = 15
    processed_files = 0
    chunk_number = 0
    
    files.each_slice(chunk_size) do |chunk|
      chunk_number += 1
      Rails.logger.info "Processing chunk #{chunk_number} with #{chunk.length} files"
      
      # Convert metadata to the format expected by PhotoImportJob
      chunk_data = chunk.map do |file_info|
        {
          'original_filename' => file_info['name'],
          'content_type' => file_info['type'],
          'file_size' => file_info['size'],
          'webkit_relative_path' => file_info['webkitRelativePath']
        }
      end
      
      Rails.logger.info "Chunk #{chunk_number} data: #{chunk_data.map { |f| f['original_filename'] }}"
      
      enqueue_chunk(chunk_data, user_id)
      processed_files += chunk.length
      
      Rails.logger.info "Enqueued chunk #{chunk_number}, total processed: #{processed_files}"
      
      # Small delay between chunks
      sleep(0.1)
    end
    
    Rails.logger.info "=== PROCESS FILE METADATA COMPLETED ==="
    Rails.logger.info "Total processed: #{processed_files} files in #{chunk_number} chunks"
  end

  def process_actual_files(temp_directory, user_id)
    Rails.logger.info "Processing actual files from directory: #{temp_directory}"
    
    uploaded_files_data = []
    total_files = 0
    processed_files = 0
    
    Dir.glob(File.join(temp_directory, '**', '*')).each do |file_path|
      next unless File.file?(file_path)
      total_files += 1
      
      begin
        # Get file info
        original_filename = File.basename(file_path)
        file_size = File.size(file_path)
        
        # Determine content type
        content_type = case File.extname(original_filename).downcase
        when '.jpg', '.jpeg' then 'image/jpeg'
        when '.png' then 'image/png'
        when '.gif' then 'image/gif'
        when '.bmp' then 'image/bmp'
        when '.tiff', '.tif' then 'image/tiff'
        when '.webp' then 'image/webp'
        when '.heic' then 'image/heic'
        when '.heif' then 'image/heif'
        else 'application/octet-stream'
        end
        
        # Skip non-image files
        unless content_type.start_with?('image/')
          Rails.logger.debug "Skipping non-image file: #{original_filename}"
          next
        end
        
        # Add to upload data
        uploaded_files_data << {
          'temp_path' => file_path,
          'original_filename' => original_filename,
          'content_type' => content_type,
          'file_size' => file_size
        }
        
        processed_files += 1
        
        # Process in chunks to avoid "Too many open files" error
        if uploaded_files_data.length >= 15
          enqueue_chunk(uploaded_files_data, user_id)
          uploaded_files_data = []
          sleep(0.1)
        end
        
      rescue => e
        Rails.logger.error "Error processing file #{file_path}: #{e.message}"
      end
    end
    
    # Enqueue any remaining files
    if uploaded_files_data.any?
      enqueue_chunk(uploaded_files_data, user_id)
    end
    
    Rails.logger.info "Processed #{processed_files} files out of #{total_files} total files"
  end

  private

  def enqueue_chunk(files_data, user_id)
    Rails.logger.info "=== ENQUEUE CHUNK START ==="
    Rails.logger.info "Enqueuing PhotoImportJob chunk with #{files_data.length} files"
    Rails.logger.info "User ID: #{user_id}"
    Rails.logger.info "Files in chunk: #{files_data.map { |f| f['original_filename'] }}"
    
    job_id = PhotoImportJob.perform_async(files_data, user_id)
    
    Rails.logger.info "Successfully enqueued PhotoImportJob with ID: #{job_id}"
    Rails.logger.info "Job arguments: files_data=#{files_data.length} files, user_id=#{user_id}"
    Rails.logger.info "=== ENQUEUE CHUNK COMPLETED ==="
  rescue => e
    Rails.logger.error "=== ENQUEUE CHUNK FAILED ==="
    Rails.logger.error "Failed to enqueue chunk of #{files_data.length} files: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
    # Don't raise - continue with other chunks
  end
end
