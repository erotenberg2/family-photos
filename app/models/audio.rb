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
    ["album", "artist", "bitrate", "created_at", "description", "duration", 
     "genre", "id", "title", "updated_at"]
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

  # Check if post-processing has been completed
  def post_processed?
    # Audio post-processing completed if metadata fields are populated
    duration.present? && bitrate.present?
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
