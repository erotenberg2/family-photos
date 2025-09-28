class MediumPostProcessJob < ApplicationJob
  queue_as :default

  def perform(medium_id, batch_id = nil)
    medium = Medium.find_by(id: medium_id)
    
    unless medium
      Rails.logger.error "MediumPostProcessJob: Medium with ID #{medium_id} not found"
      return
    end

    Rails.logger.info "🔄 Starting async post-processing for Medium ##{medium.id}: #{medium.original_filename}"
    
    # Update processing start time
    processing_started_at = Time.current
    medium.update_columns(processing_started_at: processing_started_at)
    
    # Update Redis progress
    if batch_id
      ProgressTrackerService.update_post_processing_progress(batch_id, medium.original_filename, 'processing')
    end
    
    begin
      # Call the existing post-processing logic
      Medium.post_process_media(medium)
      
      # Update processing completion time
      medium.update_columns(processing_completed_at: Time.current)
      
      Rails.logger.info "✅ Async post-processing completed for Medium ##{medium.id}: #{medium.original_filename}"
      
      # Update Redis progress
      if batch_id
        ProgressTrackerService.update_post_processing_progress(batch_id, medium.original_filename, 'completed')
        
        # Check if this batch is complete
        check_and_complete_batch(batch_id)
      end
      
    rescue => e
      Rails.logger.error "❌ Async post-processing failed for Medium ##{medium.id} (#{medium.original_filename}): #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      
      # Still update completion time to mark as processed (even if failed)
      medium.update_columns(processing_completed_at: Time.current)
      
      # Update Redis progress
      if batch_id
        ProgressTrackerService.update_post_processing_progress(batch_id, medium.original_filename, 'failed', e.message)
        
        # Check if this batch is complete
        check_and_complete_batch(batch_id)
      end
      
      # Re-raise the error so Sidekiq can handle retries
      raise e
    end
  end

  private

  def check_and_complete_batch(batch_id)
    batch_data = ProgressTrackerService.get_post_processing_batch(batch_id)
    return unless batch_data

    total_processed = batch_data['processed_media'] + batch_data['failed_media']
    
    if total_processed >= batch_data['total_media']
      ProgressTrackerService.complete_post_processing_batch(batch_id)
    end
  end
end
