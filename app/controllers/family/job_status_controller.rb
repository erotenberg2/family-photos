class Family::JobStatusController < ApplicationController
  before_action :authenticate_user!
  
  def index
    # Get Sidekiq job stats
    stats = Sidekiq::Stats.new
    queues = Sidekiq::Queue.all
    workers = Sidekiq::Workers.new
    
    # Calculate job counts
    processing_jobs = workers.size
    queued_jobs = stats.enqueued
    completed_jobs = stats.processed
    
    # Get info about oldest job
    oldest_job_time = nil
    if processing_jobs > 0
      # Find the oldest running job
      workers.each do |process_id, thread_id, work|
        job_started_at = Time.at(work['run_at'])
        if oldest_job_time.nil? || job_started_at < oldest_job_time
          oldest_job_time = job_started_at
        end
      end
    end
    
    # Format the oldest job time
    oldest_job_time_formatted = if oldest_job_time
      time_ago_in_words(oldest_job_time)
    else
      nil
    end
    
    # Check specifically for PhotoImportJob
    photo_import_jobs = 0
    queues.each do |queue|
      queue.each do |job|
        if job.klass == 'PhotoImportJob'
          photo_import_jobs += 1
        end
      end
    end
    
    render json: {
      processing_jobs: processing_jobs,
      queued_jobs: queued_jobs,
      completed_jobs: completed_jobs,
      photo_import_jobs: photo_import_jobs,
      oldest_job_time: oldest_job_time_formatted,
      total_failed: stats.failed,
      timestamp: Time.current.to_i
    }
  rescue => e
    Rails.logger.error "Error fetching job status: #{e.message}"
    render json: {
      error: true,
      message: "Unable to fetch job status",
      processing_jobs: 0,
      queued_jobs: 0,
      completed_jobs: 0,
      photo_import_jobs: 0,
      oldest_job_time: nil,
      total_failed: 0,
      timestamp: Time.current.to_i
    }
  end
  
  private
  
  def time_ago_in_words(time)
    distance_in_seconds = Time.current - time
    
    case distance_in_seconds
    when 0..59
      "#{distance_in_seconds.to_i} seconds ago"
    when 60..3599
      "#{(distance_in_seconds / 60).to_i} minutes ago"
    when 3600..86399
      "#{(distance_in_seconds / 3600).to_i} hours ago"
    else
      "#{(distance_in_seconds / 86400).to_i} days ago"
    end
  end
end
