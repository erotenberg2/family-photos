module Constants
  MEDIA_FOLDER = "Family Album"
  ROOT_MEDIA_STORAGE = File.expand_path("~/Desktop/#{MEDIA_FOLDER}")
  
  # Storage paths
  UNSORTED_STORAGE = File.join(ROOT_MEDIA_STORAGE, "unsorted")
  DAILY_STORAGE = File.join(ROOT_MEDIA_STORAGE, "daily")
  EVENTS_STORAGE = File.join(ROOT_MEDIA_STORAGE, "events")
  
  # Internal app storage for thumbnails and previews
  ROOT_THUMB_AND_PREVIEW = File.expand_path("~/Desktop/Family Album Internals")
  THUMBNAILS_STORAGE = File.join(ROOT_THUMB_AND_PREVIEW, "thumbs")
  PREVIEWS_STORAGE = File.join(ROOT_THUMB_AND_PREVIEW, "previews")
  
  # Event hierarchy depth limit
  EVENT_RECURSION_DEPTH = 3
  
  # Media type icons
  CAMERA_ICON = "📷"
  AUDIO_ICON = "🎵"
  VIDEO_ICON = "🎬"
  FILE_ICON = "📄"
  
  # Icon mapping by medium type
  MEDIUM_TYPE_ICONS = {
    'photo' => CAMERA_ICON,
    'audio' => AUDIO_ICON,
    'video' => VIDEO_ICON
  }.freeze
  
  def self.icon_for_medium_type(medium_type)
    MEDIUM_TYPE_ICONS[medium_type] || FILE_ICON
  end
end
