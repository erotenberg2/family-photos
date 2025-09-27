class PhotoImportJob
  include Sidekiq::Job

  def perform(uploaded_files_data, user_id)
    Rails.logger.info "=== PHOTO IMPORT JOB START ==="
    Rails.logger.info "Job started with user_id: #{user_id}"
    Rails.logger.info "Files data count: #{uploaded_files_data.length}"
    Rails.logger.info "First file data: #{uploaded_files_data.first}"
    
    user = User.find(user_id)
    Rails.logger.info "Found user: #{user.email}"
    
    imported_count = 0
    errors = []
    
    Rails.logger.info "Starting photo import job for user #{user.id} with #{uploaded_files_data.length} files"
    
    uploaded_files_data.each_with_index do |file_data, index|
      begin
        # Update progress
        progress_percent = ((index + 1).to_f / uploaded_files_data.length * 100).round(1)
        Rails.logger.info "Processing file #{index + 1}/#{uploaded_files_data.length} (#{progress_percent}%)"
        Rails.logger.info "File data: #{file_data}"
        
        # Process the uploaded file data
        result = process_single_file(file_data, user)
        
        if result[:success]
          imported_count += 1
          Rails.logger.info "Successfully imported: #{result[:filename]}"
        else
          errors << result[:error]
          Rails.logger.error "Failed to import #{result[:filename]}: #{result[:error]}"
        end
        
      rescue => e
        error_msg = "#{file_data[:original_filename]}: #{e.message}"
        errors << error_msg
        Rails.logger.error "Photo import error: #{error_msg}"
        Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      end
    end
    
    Rails.logger.info "=== PHOTO IMPORT JOB COMPLETED ==="
    Rails.logger.info "Photo import job completed. Imported: #{imported_count}, Errors: #{errors.length}"
    
    # You could send a notification email here or update a status record
    # NotificationMailer.import_complete(user, imported_count, errors).deliver_now
    
    { imported_count: imported_count, errors: errors }
  end

  private

  def process_single_file(file_data, user)
    Rails.logger.info "=== PROCESS SINGLE FILE START ==="
    Rails.logger.info "Processing file data: #{file_data}"
    
    # Check if this is metadata-based (no temp_path) or file-based (has temp_path)
    if file_data['temp_path']
      # Traditional file-based approach
      process_file_based_import(file_data, user)
    else
      # Metadata-based approach - we can't process without actual files
      Rails.logger.error "Cannot process file without actual file data: #{file_data['original_filename']}"
      { success: false, filename: file_data['original_filename'], error: "File data not available - need actual file upload" }
    end
  end

  def process_file_based_import(file_data, user)
    temp_path = file_data['temp_path']
    Rails.logger.info "Looking for temp_path: #{temp_path}"
    
    begin
      # Validate it's an image
      unless file_data['content_type'].start_with?('image/')
        Rails.logger.error "Not a valid image file: #{file_data['content_type']}"
        return { success: false, filename: file_data['original_filename'], error: "Not a valid image file" }
      end
      
      # Validate temp file exists
      unless File.exist?(temp_path)
        Rails.logger.error "Temporary file not found: #{temp_path}"
        return { success: false, filename: file_data['original_filename'], error: "Temporary file not found" }
      end
      
      # Generate unique file path
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      random_suffix = SecureRandom.hex(4)
      file_extension = File.extname(file_data['original_filename'])
      stored_filename = "#{timestamp}_#{random_suffix}#{file_extension}"
      
      # Create upload directory if it doesn't exist
      upload_dir = Rails.root.join('storage', 'photos')
      FileUtils.mkdir_p(upload_dir) unless Dir.exist?(upload_dir)
      
      # Full file path
      file_path = upload_dir.join(stored_filename).to_s
      
      # Move file from temp to permanent location
      FileUtils.mv(temp_path, file_path)
      
      # Calculate MD5 hash
      md5_hash = Digest::MD5.file(file_path).hexdigest
      
      # Check for duplicates
      existing_photo = Photo.find_by(md5_hash: md5_hash)
      if existing_photo
        File.delete(file_path) # Clean up duplicate file
        return { success: false, filename: file_data['original_filename'], error: "Duplicate photo already exists" }
      end
      
      # Extract image dimensions using MiniMagick
      require 'mini_magick'
      image = MiniMagick::Image.open(file_path)
      width = image.width
      height = image.height
      
      # Create Photo record
      Rails.logger.info "Creating Photo record with:"
      Rails.logger.info "  - title: #{File.basename(file_data['original_filename'], '.*').humanize}"
      Rails.logger.info "  - file_path: #{file_path}"
      Rails.logger.info "  - original_filename: #{file_data['original_filename']}"
      Rails.logger.info "  - content_type: #{file_data['content_type']}"
      Rails.logger.info "  - file_size: #{File.size(file_path)}"
      Rails.logger.info "  - width: #{width}, height: #{height}"
      Rails.logger.info "  - md5_hash: #{md5_hash}"
      Rails.logger.info "  - user_id: #{user.id}"
      
      photo = Photo.new(
        title: File.basename(file_data['original_filename'], '.*').humanize,
        file_path: file_path,
        original_filename: file_data['original_filename'],
        content_type: file_data['content_type'],
        file_size: File.size(file_path),
        width: width,
        height: height,
        md5_hash: md5_hash,
        user: user,
        uploaded_by: user
      )
      
      if photo.save
        Rails.logger.info "Successfully created Photo record with ID: #{photo.id}"
      else
        Rails.logger.error "Failed to create Photo record:"
        Rails.logger.error "  - Errors: #{photo.errors.full_messages}"
        Rails.logger.error "  - Valid: #{photo.valid?}"
        return { success: false, filename: file_data['original_filename'], error: "Photo creation failed: #{photo.errors.full_messages.join(', ')}" }
      end
      
      # Extract EXIF data and generate thumbnail (happens in after_create callbacks)
      
      { success: true, filename: file_data['original_filename'], photo_id: photo.id }
      
    rescue => e
      # Clean up files if photo creation failed
      File.delete(file_path) if defined?(file_path) && File.exist?(file_path)
      File.delete(temp_path) if File.exist?(temp_path)
      { success: false, filename: file_data['original_filename'], error: e.message }
    ensure
      # Always clean up temp file if it still exists
      File.delete(temp_path) if File.exist?(temp_path)
    end
  end
end
