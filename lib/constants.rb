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
  
  # Storage state icons  NOTE CHANGES MADE HERE MUST ALSO BE REFLECTED IN MEDIUM_SORTER.JS 
  UNSORTED_ICON = "📥"
  DAILY_ICON = "📅"
  EVENT_ROOT_ICON = "✈️"
  SUBEVENT_LEVEL1_ICON = "✈️📂"
  SUBEVENT_LEVEL2_ICON = "✈️📂📂"
  
  # Icon mapping by medium type
  MEDIUM_TYPE_ICONS = {
    'photo' => CAMERA_ICON,
    'audio' => AUDIO_ICON,
    'video' => VIDEO_ICON
  }.freeze
  
  def self.icon_for_medium_type(medium_type)
    MEDIUM_TYPE_ICONS[medium_type] || FILE_ICON
  end
  
  def self.icon_for_storage_state(storage_state)
    case storage_state.to_sym
    when :unsorted
      UNSORTED_ICON
    when :daily
      DAILY_ICON
    when :event_root
      EVENT_ROOT_ICON
    when :subevent_level1
      SUBEVENT_LEVEL1_ICON
    when :subevent_level2
      SUBEVENT_LEVEL2_ICON
    else
      ""
    end
  end
end
