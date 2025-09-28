class ProgressTrackerService
  def self.redis
    @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
  end

  # Upload Progress Tracking
  def self.start_upload_session(session_id, user_id, total_files)
    data = {
      session_id: session_id,
      user_id: user_id,
      status: 'uploading',
      total_files: total_files,
      uploaded_files: 0,
      failed_files: 0,
      current_file: nil,
      started_at: Time.current.iso8601,
      updated_at: Time.current.iso8601,
      batches: []
    }
    
    redis.setex("upload_session:#{session_id}", 3600, data.to_json) # Expire after 1 hour
    Rails.logger.info "📊 Started upload session tracking: #{session_id}"
  end

  def self.start_upload_batch(session_id, batch_id, batch_files_count)
    session_data = get_upload_session(session_id)
    return unless session_data

    batch_data = {
      batch_id: batch_id,
      files_count: batch_files_count,
      uploaded: 0,
      failed: 0,
      started_at: Time.current.iso8601,
      status: 'uploading'
    }

    session_data['batches'] << batch_data
    session_data['updated_at'] = Time.current.iso8601
    
    redis.setex("upload_session:#{session_id}", 3600, session_data.to_json)
    Rails.logger.info "📊 Started batch tracking: #{batch_id} (#{batch_files_count} files)"
  end

  def self.update_upload_progress(session_id, batch_id, filename, status, error_msg = nil)
    session_data = get_upload_session(session_id)
    return unless session_data

    # Update session totals
    if status == 'uploaded'
      session_data['uploaded_files'] += 1
    elsif status == 'failed'
      session_data['failed_files'] += 1
    end
    
    session_data['current_file'] = filename
    session_data['updated_at'] = Time.current.iso8601

    # Update batch progress
    batch = session_data['batches'].find { |b| b['batch_id'] == batch_id }
    if batch
      if status == 'uploaded'
        batch['uploaded'] += 1
      elsif status == 'failed'
        batch['failed'] += 1
      end
      batch['current_file'] = filename
    end

    redis.setex("upload_session:#{session_id}", 3600, session_data.to_json)
  end

  def self.complete_upload_batch(session_id, batch_id)
    session_data = get_upload_session(session_id)
    return unless session_data

    batch = session_data['batches'].find { |b| b['batch_id'] == batch_id }
    if batch
      batch['status'] = 'completed'
      batch['completed_at'] = Time.current.iso8601
    end

    session_data['updated_at'] = Time.current.iso8601
    redis.setex("upload_session:#{session_id}", 3600, session_data.to_json)
    Rails.logger.info "📊 Completed batch: #{batch_id}"
  end

  def self.complete_upload_session(session_id)
    session_data = get_upload_session(session_id)
    return unless session_data

    session_data['status'] = 'completed'
    session_data['completed_at'] = Time.current.iso8601
    session_data['updated_at'] = Time.current.iso8601
    
    redis.setex("upload_session:#{session_id}", 3600, session_data.to_json)
    Rails.logger.info "📊 Completed upload session: #{session_id}"
  end

  def self.get_upload_session(session_id)
    data = redis.get("upload_session:#{session_id}")
    data ? JSON.parse(data) : nil
  end

  # Post-Processing Progress Tracking
  def self.start_post_processing_batch(batch_id, session_id, total_media_count)
    data = {
      batch_id: batch_id,
      session_id: session_id,
      status: 'processing',
      total_media: total_media_count,
      processed_media: 0,
      failed_media: 0,
      current_medium: nil,
      started_at: Time.current.iso8601,
      updated_at: Time.current.iso8601
    }
    
    redis.setex("post_process_batch:#{batch_id}", 3600, data.to_json)
    Rails.logger.info "📊 Started post-processing batch tracking: #{batch_id} (#{total_media_count} media)"
  end

  def self.update_post_processing_progress(batch_id, medium_filename, status, error_msg = nil)
    data = get_post_processing_batch(batch_id)
    return unless data

    if status == 'completed'
      data['processed_media'] += 1
    elsif status == 'failed'
      data['failed_media'] += 1
    end
    
    data['current_medium'] = medium_filename
    data['updated_at'] = Time.current.iso8601
    
    redis.setex("post_process_batch:#{batch_id}", 3600, data.to_json)
  end

  def self.complete_post_processing_batch(batch_id)
    data = get_post_processing_batch(batch_id)
    return unless data

    data['status'] = 'completed'
    data['completed_at'] = Time.current.iso8601
    data['updated_at'] = Time.current.iso8601
    
    redis.setex("post_process_batch:#{batch_id}", 3600, data.to_json)
    Rails.logger.info "📊 Completed post-processing batch: #{batch_id}"
  end

  def self.get_post_processing_batch(batch_id)
    data = redis.get("post_process_batch:#{batch_id}")
    data ? JSON.parse(data) : nil
  end

  # Dashboard Data Aggregation
  def self.get_all_active_sessions(user_id = nil)
    upload_sessions = []
    post_processing_batches = []

    # Get all upload sessions
    redis.scan_each(match: "upload_session:*") do |key|
      session_data = JSON.parse(redis.get(key))
      next if user_id && session_data['user_id'] != user_id
      next if session_data['status'] == 'completed' && Time.parse(session_data['updated_at']) < 5.minutes.ago
      
      upload_sessions << session_data
    end

    # Get all post-processing batches
    redis.scan_each(match: "post_process_batch:*") do |key|
      batch_data = JSON.parse(redis.get(key))
      next if batch_data['status'] == 'completed' && Time.parse(batch_data['updated_at']) < 5.minutes.ago
      
      post_processing_batches << batch_data
    end

    {
      upload_sessions: upload_sessions.sort_by { |s| s['started_at'] }.reverse,
      post_processing_batches: post_processing_batches.sort_by { |b| b['started_at'] }.reverse
    }
  end

  # Cleanup old entries
  def self.cleanup_old_entries
    cleaned_count = 0
    
    # Clean upload sessions older than 2 hours
    redis.scan_each(match: "upload_session:*") do |key|
      session_data = JSON.parse(redis.get(key))
      if Time.parse(session_data['updated_at']) < 2.hours.ago
        redis.del(key)
        cleaned_count += 1
      end
    end

    # Clean post-processing batches older than 2 hours
    redis.scan_each(match: "post_process_batch:*") do |key|
      batch_data = JSON.parse(redis.get(key))
      if Time.parse(batch_data['updated_at']) < 2.hours.ago
        redis.del(key)
        cleaned_count += 1
      end
    end

    Rails.logger.info "🧹 Cleaned up #{cleaned_count} old progress entries from Redis"
    cleaned_count
  end
end
