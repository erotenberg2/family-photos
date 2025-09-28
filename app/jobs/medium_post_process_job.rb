class MediumPostProcessJob < ApplicationJob
  queue_as :default

  def perform(medium_id)
    medium = Medium.find_by(id: medium_id)
    
    unless medium
      Rails.logger.error "MediumPostProcessJob: Medium with ID #{medium_id} not found"
      return
    end

    Rails.logger.info "🔄 Starting async post-processing for Medium ##{medium.id}: #{medium.original_filename}"
    
    # Update processing start time
    processing_started_at = Time.current
    medium.update_columns(processing_started_at: processing_started_at)
    
    begin
      # Call the existing post-processing logic
      Medium.post_process_media(medium)
      
      # Update processing completion time
      medium.update_columns(processing_completed_at: Time.current)
      
      Rails.logger.info "✅ Async post-processing completed for Medium ##{medium.id}: #{medium.original_filename}"
      
    rescue => e
      Rails.logger.error "❌ Async post-processing failed for Medium ##{medium.id} (#{medium.original_filename}): #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      
      # Still update completion time to mark as processed (even if failed)
      medium.update_columns(processing_completed_at: Time.current)
      
      # Re-raise the error so Sidekiq can handle retries
      raise e
    end
  end
end
