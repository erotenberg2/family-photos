class BatchPostProcessJob < ApplicationJob
  queue_as :default

  def perform(batch_id, session_id)
    Rails.logger.info "🔄 Starting batch post-processing for batch: #{batch_id}, session: #{session_id}"
    
    # Find all media from this batch that need post-processing
    media_to_process = Medium.where(
      upload_batch_id: batch_id,
      upload_session_id: session_id,
      processing_started_at: nil
    )
    
    if media_to_process.empty?
      Rails.logger.info "⏭️ No media to post-process for batch: #{batch_id}"
      return
    end
    
    Rails.logger.info "📋 Found #{media_to_process.count} media files to post-process in batch: #{batch_id}"
    
    # Start Redis progress tracking for post-processing
    ProgressTrackerService.start_post_processing_batch(batch_id, session_id, media_to_process.count)
    
    # Enqueue individual post-processing jobs for each medium
    media_to_process.each do |medium|
      Rails.logger.info "🚀 Enqueuing post-processing job for Medium ##{medium.id}: #{medium.original_filename}"
      MediumPostProcessJob.perform_later(medium.id, batch_id)
    end
    
    Rails.logger.info "✅ Enqueued #{media_to_process.count} post-processing jobs for batch: #{batch_id}"
  end
end
