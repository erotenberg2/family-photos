namespace :post_process do
  desc "Enqueue post-processing jobs for all unprocessed media"
  task all: :environment do
    puts "Finding unprocessed media..."
    
    unprocessed_media = Medium.post_processing_not_started
    count = unprocessed_media.count
    
    if count == 0
      puts "No unprocessed media found."
      return
    end
    
    puts "Enqueuing post-processing jobs for #{count} media files..."
    
    unprocessed_media.each do |medium|
      MediumPostProcessJob.perform_later(medium.id)
    end
    
    puts "✅ Enqueued #{count} post-processing jobs"
  end
  
  desc "Enqueue post-processing jobs for a specific batch"
  task :batch, [:batch_id] => :environment do |t, args|
    batch_id = args[:batch_id]
    
    unless batch_id
      puts "Usage: rake post_process:batch[BATCH_ID]"
      exit 1
    end
    
    puts "Finding unprocessed media for batch: #{batch_id}..."
    
    unprocessed_media = Medium.needing_post_processing(batch_id: batch_id)
    count = unprocessed_media.count
    
    if count == 0
      puts "No unprocessed media found for batch: #{batch_id}"
      return
    end
    
    puts "Enqueuing post-processing jobs for #{count} media files in batch: #{batch_id}..."
    
    unprocessed_media.each do |medium|
      MediumPostProcessJob.perform_later(medium.id)
    end
    
    puts "✅ Enqueued #{count} post-processing jobs for batch: #{batch_id}"
  end
  
  desc "Show post-processing statistics"
  task stats: :environment do
    stats = Medium.post_processing_stats
    
    puts "📊 Post-Processing Statistics:"
    puts "  Total Media: #{stats[:total]}"
    puts "  Not Started: #{stats[:not_started]}"
    puts "  In Progress: #{stats[:in_progress]}"
    puts "  Completed: #{stats[:completed]}"
    
    if stats[:total] > 0
      completion_rate = (stats[:completed].to_f / stats[:total] * 100).round(1)
      puts "  Completion Rate: #{completion_rate}%"
    end
  end
end
