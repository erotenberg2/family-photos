class PhotoImportJob
  include Sidekiq::Job

  def perform(uploaded_files_data, user_id)
    user = User.find(user_id)
    imported_count = 0
    errors = []
    
    Rails.logger.info "Starting photo import job for user #{user.id} with #{uploaded_files_data.length} files"
    
    uploaded_files_data.each_with_index do |file_data, index|
      begin
        # Update progress
        progress_percent = ((index + 1).to_f / uploaded_files_data.length * 100).round(1)
        Rails.logger.info "Processing file #{index + 1}/#{uploaded_files_data.length} (#{progress_percent}%)"
        
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
      end
    end
    
    Rails.logger.info "Photo import job completed. Imported: #{imported_count}, Errors: #{errors.length}"
    
    # You could send a notification email here or update a status record
    # NotificationMailer.import_complete(user, imported_count, errors).deliver_now
    
    { imported_count: imported_count, errors: errors }
  end

  private

  def process_single_file(file_data, user)
    temp_path = file_data['temp_path']
    
    begin
      # Validate it's an image
      unless file_data['content_type'].start_with?('image/')
        return { success: false, filename: file_data['original_filename'], error: "Not a valid image file" }
      end
      
      # Validate temp file exists
      unless File.exist?(temp_path)
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
      photo = Photo.create!(
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
