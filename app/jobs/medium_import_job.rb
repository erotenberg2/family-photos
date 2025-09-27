class MediumImportJob
  include Sidekiq::Job

  def perform(uploaded_files_data, user_id)
    Rails.logger.info "=== MEDIUM IMPORT JOB START ==="
    Rails.logger.info "Job started with user_id: #{user_id}"
    Rails.logger.info "Files data count: #{uploaded_files_data.length}"
    Rails.logger.info "First file data: #{uploaded_files_data.first}"
    
    user = User.find(user_id)
    Rails.logger.info "Found user: #{user.email}"
    
    imported_count = 0
    errors = []
    
    Rails.logger.info "Starting medium import job for user #{user.id} with #{uploaded_files_data.length} files"
    
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
        error_msg = "#{file_data['original_filename']}: #{e.message}"
        errors << error_msg
        Rails.logger.error "Medium import error: #{error_msg}"
        Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      end
    end
    
    Rails.logger.info "=== MEDIUM IMPORT JOB COMPLETED ==="
    Rails.logger.info "Medium import job completed. Imported: #{imported_count}, Errors: #{errors.length}"
    
    # You could send a notification email here or update a status record
    # NotificationMailer.import_complete(user, imported_count, errors).deliver_now
    
    { imported_count: imported_count, errors: errors }
  end

  private

  def process_single_file(file_data, user)
    Rails.logger.info "Processing single file: #{file_data['original_filename']}"
    
    begin
      # Create a temporary uploaded file object
      uploaded_file = create_uploaded_file_from_data(file_data)
      
      # Use Medium.create_from_uploaded_file for the import
      result = Medium.create_from_uploaded_file(uploaded_file, user)
      
      if result[:success]
        Rails.logger.info "✅ Successfully imported #{file_data['original_filename']} as #{result[:medium].medium_type}"
        {
          success: true,
          filename: file_data['original_filename'],
          medium: result[:medium]
        }
      elsif result[:existing]
        Rails.logger.info "⚠️ Duplicate file skipped: #{file_data['original_filename']}"
        {
          success: false,
          filename: file_data['original_filename'],
          error: "Duplicate file (MD5: #{result[:existing].md5_hash})"
        }
      else
        Rails.logger.error "❌ Failed to import #{file_data['original_filename']}: #{result[:error]}"
        {
          success: false,
          filename: file_data['original_filename'],
          error: result[:error]
        }
      end
      
    rescue => e
      Rails.logger.error "Exception processing #{file_data['original_filename']}: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      
      {
        success: false,
        filename: file_data['original_filename'],
        error: e.message
      }
    end
  end

  def create_uploaded_file_from_data(file_data)
    Rails.logger.info "Creating uploaded file from data for: #{file_data['original_filename']}"
    
    if file_data['tempfile_path'] && File.exist?(file_data['tempfile_path'])
      # Use existing tempfile if available
      Rails.logger.info "Using existing tempfile: #{file_data['tempfile_path']}"
      tempfile = File.open(file_data['tempfile_path'])
    else
      # Create tempfile from base64 data
      Rails.logger.info "Creating tempfile from base64 data"
      tempfile = Tempfile.new(['upload', File.extname(file_data['original_filename'])])
      tempfile.binmode
      tempfile.write(Base64.decode64(file_data['file_data']))
      tempfile.rewind
    end
    
    # Create an ActionDispatch::Http::UploadedFile-like object
    uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: tempfile,
      filename: file_data['original_filename'],
      type: file_data['content_type'],
      head: "Content-Disposition: form-data; name=\"file\"; filename=\"#{file_data['original_filename']}\"\r\nContent-Type: #{file_data['content_type']}\r\n"
    )
    
    Rails.logger.info "Created uploaded file: #{uploaded_file.original_filename} (#{uploaded_file.content_type})"
    uploaded_file
  end
end
