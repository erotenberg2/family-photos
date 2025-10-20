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
end
