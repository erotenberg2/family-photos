namespace :upload_logs do
  desc "Auto-complete stale upload sessions (older than 1 hour)"
  task auto_complete_stale: :environment do
    puts "Checking for stale upload sessions..."
    
    completed_count = UploadLog.auto_complete_stale_sessions!
    
    if completed_count > 0
      puts "Auto-completed #{completed_count} stale upload session(s)"
    else
      puts "No stale upload sessions found"
    end
  end
  
  desc "Clean up old completed upload logs (older than 30 days)"
  task cleanup_old: :environment do
    puts "Cleaning up old upload logs..."
    
    old_logs = UploadLog.completed.where('created_at < ?', 30.days.ago)
    count = old_logs.count
    
    if count > 0
      old_logs.destroy_all
      puts "Deleted #{count} old upload log(s)"
    else
      puts "No old upload logs to clean up"
    end
  end
end
