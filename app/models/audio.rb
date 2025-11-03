class Audio < ApplicationRecord
  has_one :medium, as: :mediable, dependent: :destroy
  
  # Define valid file types for audio
  def self.valid_types
    {
      # Standard MIME types => file extensions, make sure this matches the media_import_popup.js file
      'audio/mpeg' => ['.mp3'],
      'audio/mp3' => ['.mp3'],
      'audio/mpg' => ['.mp3'],
      'audio/x-mpeg' => ['.mp3'],
      'audio/x-mpeg-3' => ['.mp3'],
      'audio/x-mp3' => ['.mp3'],
      'audio/wav' => ['.wav'],
      'audio/x-wav' => ['.wav'],
      'audio/wave' => ['.wav'],
      'audio/aac' => ['.aac', '.m4a'],
      'audio/aacp' => ['.aac', '.m4a'],
      'audio/mp4' => ['.m4a'],
      'audio/x-m4a' => ['.m4a'],
      'audio/ogg' => ['.ogg', '.oga'],
      'audio/vorbis' => ['.ogg'],
      'audio/flac' => ['.flac'],
      'audio/x-flac' => ['.flac'],
      'audio/webm' => ['.weba'],
      'audio/m4a' => ['.m4a']
    }
  end
  
  # Delegate generic media attributes to Medium
  delegate :file_size, :original_filename, :current_filename, :content_type, :md5_hash,
           :uploaded_by, :user, :file_size_human, :effective_datetime,
           :has_valid_datetime?, :datetime_source, :file_exists?, to: :medium, allow_nil: true
           
  # Note: Medium creates Audio, not the other way around

  def self.ransackable_attributes(auth_object = nil)
    ["album", "album_artist", "artist", "bitrate", "bpm", "comment", "compilation", 
     "composer", "copyright", "created_at", "description", "disc_number", "duration", 
     "genre", "id", "isrc", "publisher", "title", "track", "updated_at", "year"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["medium"]
  end

  # Scopes  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_artist, ->(artist) { where(artist: artist) }
  scope :by_album, ->(album) { where(album: album) }
  scope :by_genre, ->(genre) { where(genre: genre) }
  
  # Scopes that work with Medium
  scope :by_date, -> { joins(:medium).order('media.datetime_user, media.datetime_intrinsic, media.datetime_inferred, media.created_at') }
  scope :by_file_type, ->(type) { joins(:medium).where(media: { content_type: type }) }

  # Intrinsic datetime from metadata (for future implementation)
  def datetime_intrinsic
    # TODO: Extract datetime from audio metadata when audio metadata extraction is implemented
    nil
  end

  # Extract metadata from audio file using ffprobe/ffmpeg
  def extract_metadata_from_ffprobe
    return unless medium&.full_file_path.present? && File.exist?(medium.full_file_path)
    
    begin
      require 'open3'
      
      # Use ffprobe to get detailed metadata
      ffprobe_cmd = [
        'ffprobe',
        '-v', 'error',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        medium.full_file_path
      ]
      
      stdout, stderr, status = Open3.capture3(*ffprobe_cmd)
      
      if status.success? && stdout.present?
        data = JSON.parse(stdout)
        format_info = data['format']
        stream_info = data['streams']&.first
        
        # Extract metadata from format tags
        tags = format_info['tags'] || {}
        
        # Core metadata
        self.title = tags['title']&.strip
        self.artist = tags['artist']&.strip
        self.album = tags['album']&.strip
        self.genre = tags['genre']&.strip
        self.comment = tags['comment']&.strip
        self.track = tags['track']&.strip
        self.year = tags['date']&.strip&.to_i rescue nil
        
        # Extended metadata
        self.album_artist = tags['album_artist']&.strip
        self.composer = tags['composer']&.strip
        self.disc_number = tags['disc']&.strip
        self.publisher = tags['publisher']&.strip || tags['label']&.strip
        self.copyright = tags['copyright']&.strip
        self.isrc = tags['ISRC']&.strip
        
        # BPM (beats per minute)
        bpm_str = tags['TBPM']&.strip || tags['BPM']&.strip
        if bpm_str.present?
          self.bpm = bpm_str.to_i
        end
        
        # Compilation flag (boolean)
        compilation_str = tags['compilation']&.strip
        if compilation_str.present?
          self.compilation = ['1', 'true', 'yes'].include?(compilation_str.downcase)
        end
        
        # Extract duration from format
        duration_str = format_info['duration']
        if duration_str.present?
          self.duration = duration_str.to_f.round
        end
        
        # Extract bitrate from format
        bitrate_str = format_info['bit_rate']
        if bitrate_str.present?
          # Convert bps to kbps
          self.bitrate = (bitrate_str.to_i / 1000.0).round
        end
        
        # Store raw metadata for reference
        self.metadata = tags
        
        Rails.logger.info "Extracted audio metadata for: #{medium.full_file_path}"
        Rails.logger.info "  Title: #{self.title}, Artist: #{self.artist}, Album: #{self.album}, Genre: #{self.genre}"
        Rails.logger.info "  Year: #{self.year}, Track: #{self.track}, Duration: #{self.duration}s, Bitrate: #{self.bitrate} kbps"
        Rails.logger.info "  Album Artist: #{self.album_artist}, Composer: #{self.composer}, Publisher: #{self.publisher}"
      else
        Rails.logger.error "FFprobe failed: #{stderr}"
      end
    rescue => e
      Rails.logger.error "Exception extracting audio metadata: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  # Check if post-processing has been completed
  def post_processed?
    # Audio post-processing completed if we've attempted metadata extraction
    # Even if no metadata was found, the file has been "processed"
    medium.present?
  end

  # Duration in human-readable format
  def duration_human
    return nil unless duration.present?
    
    seconds = duration
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60
    
    if hours > 0
      format("%d:%02d:%02d", hours, minutes, secs)
    else
      format("%d:%02d", minutes, secs)
    end
  end

  # Bitrate in human-readable format (kbps)
  def bitrate_human
    return nil unless bitrate.present?
    "#{bitrate} kbps"
  end
end
