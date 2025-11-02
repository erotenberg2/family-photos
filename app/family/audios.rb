ActiveAdmin.register Audio, namespace: :family do

  # Permitted parameters (Audio-specific attributes only)
  permit_params :title, :description, :duration, :bitrate, :artist, :album, :genre

  # Index page configuration
  index do
    selectable_column
    
    column "Icon", sortable: false do |audio|
      content_tag :div, Constants::AUDIO_ICON, style: "width: 60px; height: 60px; background: #f0f0f0; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px; cursor: pointer;"
    end
    
    column :original_filename
    column :current_filename
    column :user
    column :uploaded_by
    column :effective_datetime do |audio|
      if audio.effective_datetime
        content_tag :div, audio.effective_datetime.strftime("%Y-%m-%d %H:%M"), 
                    title: "Source: #{audio.datetime_source}"
      else
        content_tag :div, "No date", style: "color: #999;"
      end
    end
    column :artist
    column :album
    column :genre
    column "Duration" do |audio|
      audio.duration_human
    end
    column :bitrate do |audio|
      audio.bitrate_human
    end
    column "File Size" do |audio|
      audio.file_size_human
    end
    column "Storage", sortable: false do |audio|
      case audio.medium.aasm.current_state
      when :unsorted
        content_tag :div, Constants::UNSORTED_ICON, style: "font-size: 18px; text-align: center;", title: "Unsorted storage"
      when :daily
        content_tag :div, Constants::DAILY_ICON, style: "font-size: 18px; text-align: center;", title: "Daily storage"
      when :event_root
        content_tag :div, Constants::EVENT_ROOT_ICON, style: "font-size: 18px; text-align: center;", title: "Event storage"
      when :subevent_level1
        content_tag :div, Constants::SUBEVENT_LEVEL1_ICON, style: "font-size: 18px; text-align: center;", title: "Subevent level 1"
      when :subevent_level2
        content_tag :div, Constants::SUBEVENT_LEVEL2_ICON, style: "font-size: 18px; text-align: center;", title: "Subevent level 2"
      end
    end
    column :created_at
    
    actions
  end

  # Filters
  filter :title
  filter :artist
  filter :album
  filter :genre
  filter :duration
  filter :bitrate
  filter :created_at

  # Show page configuration
  show do
    attributes_table do
      row :id
      row :title
      row :description
      row :original_filename
      row "Storage Path" do |audio|
        audio.medium&.computed_directory_path || "Not set"
      end
      row :current_filename
      row :content_type
      row :file_size do |audio|
        audio.file_size_human
      end
      row :artist
      row :album
      row :genre
      row "Duration" do |audio|
        audio.duration_human
      end
      row "Bitrate" do |audio|
        audio.bitrate_human
      end
      row :effective_datetime do |audio|
        if audio.effective_datetime
          content_tag :div, audio.effective_datetime.strftime("%Y-%m-%d %H:%M:%S"), style: "font-weight: bold;"
        else
          content_tag :div, "No date available", style: "color: #cc0000; font-weight: bold;"
        end
      end
      row "Storage State" do |audio|
        case audio.medium.aasm.current_state
        when :unsorted
          content_tag :div, "#{Constants::UNSORTED_ICON} Unsorted Storage", style: "font-size: 16px;", title: "Stored in unsorted organization structure"
        when :daily
          content_tag :div, "#{Constants::DAILY_ICON} Daily Storage", style: "font-size: 16px;", title: "Stored in daily organization structure"
        when :event_root
          content_tag :div, "#{Constants::EVENT_ROOT_ICON} Event Root", style: "font-size: 16px;", title: "Stored in event organization structure"
        when :subevent_level1
          content_tag :div, "#{Constants::SUBEVENT_LEVEL1_ICON} Subevent L1", style: "font-size: 16px;", title: "Stored in subevent level 1"
        when :subevent_level2
          content_tag :div, "#{Constants::SUBEVENT_LEVEL2_ICON} Subevent L2", style: "font-size: 16px;", title: "Stored in subevent level 2"
        end
      end
      row "Event" do |audio|
        if audio.medium.event
          link_to audio.medium.event.title, family_event_path(audio.medium.event), style: "font-weight: bold;"
        else
          content_tag :div, "Not in an event", style: "color: #999;"
        end
      end
      row "Subevent" do |audio|
        if audio.medium.subevent
          link_to audio.medium.subevent.hierarchy_path, family_subevent_path(audio.medium.subevent), style: "font-weight: bold;"
        else
          content_tag :div, "Not in a subevent", style: "color: #999;"
        end
      end
      row :user
      row :uploaded_by
      row :md5_hash
      row :created_at
      row :updated_at
    end
  end

  # Form configuration
  form do |f|
    f.inputs "Audio Details" do
      f.input :title
      f.input :description
    end

    f.inputs "Metadata" do
      f.input :artist
      f.input :album
      f.input :genre
      f.input :duration
      f.input :bitrate
    end

    f.actions
  end

end

