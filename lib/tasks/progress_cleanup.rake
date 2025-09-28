namespace :progress do
  desc "Clean up old progress tracking entries from Redis"
  task cleanup: :environment do
    puts "🧹 Cleaning up old progress tracking entries..."
    
    cleaned_count = ProgressTrackerService.cleanup_old_entries
    
    puts "✅ Cleaned up #{cleaned_count} old progress entries"
    
    if cleaned_count > 0
      puts "📊 Freed up Redis memory by removing stale tracking data"
    else
      puts "💡 No old entries found - Redis is clean!"
    end
  end

  desc "Show current progress tracking statistics"
  task stats: :environment do
    puts "📊 Current Progress Tracking Statistics"
    puts "=" * 50
    
    redis = ProgressTrackerService.redis
    
    # Count upload sessions
    upload_sessions = 0
    redis.scan_each(match: "upload_session:*") { upload_sessions += 1 }
    
    # Count post-processing batches
    post_processing_batches = 0
    redis.scan_each(match: "post_process_batch:*") { post_processing_batches += 1 }
    
    puts "📤 Upload Sessions: #{upload_sessions}"
    puts "⚙️ Post-Processing Batches: #{post_processing_batches}"
    puts "🔄 Total Redis Keys: #{upload_sessions + post_processing_batches}"
    
    if upload_sessions > 0 || post_processing_batches > 0
      puts "\n📋 Recent Activity:"
      
      # Show recent upload sessions
      if upload_sessions > 0
        puts "\n📤 Upload Sessions:"
        redis.scan_each(match: "upload_session:*") do |key|
          session_data = JSON.parse(redis.get(key))
          status_emoji = session_data['status'] == 'completed' ? '✅' : '🔄'
          puts "  #{status_emoji} Session #{session_data['session_id'][0..7]}... - #{session_data['uploaded_files']}/#{session_data['total_files']} files (#{session_data['status']})"
        end
      end
      
      # Show recent post-processing batches
      if post_processing_batches > 0
        puts "\n⚙️ Post-Processing Batches:"
        redis.scan_each(match: "post_process_batch:*") do |key|
          batch_data = JSON.parse(redis.get(key))
          status_emoji = batch_data['status'] == 'completed' ? '✅' : '🔄'
          puts "  #{status_emoji} Batch #{batch_data['batch_id'][0..7]}... - #{batch_data['processed_media']}/#{batch_data['total_media']} media (#{batch_data['status']})"
        end
      end
    else
      puts "\n💤 No active progress tracking entries"
    end
    
    puts "\n" + "=" * 50
  end
end
