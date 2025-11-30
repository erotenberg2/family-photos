ActiveAdmin.register Video, namespace: :family do

  # Permitted parameters (Video-specific attributes only)
  permit_params :title, :description, :duration, :width, :height, :bitrate, 
                :camera_make, :camera_model, :metadata

  # Index page configuration
  index do
    selectable_column
    
    column "Thumbnail", sortable: false do |video|
      link_to family_video_path(video) do
        if video.thumbnail_path && File.exist?(video.thumbnail_path)
          image_tag("data:image/jpg;base64,#{Base64.encode64(File.read(video.thumbnail_path))}", 
                    style: "max-width: 60px; max-height: 60px; object-fit: cover; border-radius: 4px; cursor: pointer; transition: transform 0.2s ease; display: block;",
                    alt: video.title || video.original_filename,
                    onmouseover: "this.style.transform='scale(1.05)'",
                    onmouseout: "this.style.transform='scale(1)'")
        else
          # Show placeholder for unprocessed videos
          content_tag :div, Constants::VIDEO_ICON, style: "width: 60px; height: 60px; background: #f8f9fa; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px; cursor: pointer; border: 2px dashed #dee2e6;"
        end
      end
    end
    
    column :original_filename
    column :current_filename
    column :user
    column :uploaded_by
    column :effective_datetime do |video|
      if video.effective_datetime
        content_tag :div, video.effective_datetime.strftime("%Y-%m-%d %H:%M"), 
                    title: "Source: #{video.datetime_source}"
      else
        content_tag :div, "No date", style: "color: #999;"
      end
    end
    column "Dimensions" do |video|
      if video.width && video.height
        "#{video.width}×#{video.height}"
      else
        "Unknown"
      end
    end
    column "Duration" do |video|
      video.duration_human
    end
    column "File Size" do |video|
      video.file_size_human
    end
    column :camera_make
    column :camera_model
    column "Storage", sortable: false do |video|
      case video.medium.aasm.current_state
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
  filter :camera_make
  filter :camera_model
  filter :width
  filter :height
  filter :duration
  filter :bitrate
  filter :created_at

  # Show page configuration
  show do
    # Add CSS for hover effects
    content_for :head do
      raw <<~CSS
        <style>
          .video-thumbnail-link:hover img {
            box-shadow: 0 4px 12px rgba(0,0,0,0.2) !important;
            transform: scale(1.02);
          }
          .video-thumbnail-link img {
            transition: all 0.3s ease !important;
          }
        </style>
      CSS
    end

    # Video preview panel
    panel "Video Preview" do
      if video.file_exists?
        # Check if video format is supported by browsers
        unsupported_formats = ['video/x-ms-wmv', 'video/wmv', 'video/x-ms-asf', 'video/flv', 'video/x-flv']
        
        if unsupported_formats.include?(video.content_type)
          div do
            para "⚠️ This video format (#{video.content_type}) may not play in all browsers.", 
                 style: "color: #856404; background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 4px; margin-bottom: 15px;"
            
            li ("Download the video file to play it: " + 
                link_to("Download #{video.original_filename}", 
                        image_path(video.medium),
                        download: video.original_filename,
                        style: "font-weight: bold; color: #007bff;")).html_safe
          end
        end
        
        video_tag image_path(video.medium), 
                  controls: true, 
                  style: "max-width: 600px; max-height: 400px; margin: 0 auto; display: block;"
      else
        div "Video file not found", style: "padding: 40px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
      end
    end

    attributes_table do
      row :id
      row :title
      row :description
      row :original_filename
      row "Storage Path" do |video|
        video.medium&.computed_directory_path || "Not set"
      end
      row :current_filename
      row :content_type
      row :file_size do |video|
        video.file_size_human
      end
      row :dimensions do |video|
        if video.width && video.height
          "#{video.width} × #{video.height} pixels"
        else
          "Not available"
        end
      end
      row :thumbnail_dimensions do |video|
        if video.thumbnail_width && video.thumbnail_height
          "#{video.thumbnail_width} × #{video.thumbnail_height} pixels (#{Video::THUMBNAIL_MAX_SIZE}px max)"
        else
          "Not generated"
        end
      end
      row :preview_dimensions do |video|
        if video.preview_width && video.preview_height
          "#{video.preview_width} × #{video.preview_height} pixels (#{Video::PREVIEW_MAX_SIZE}px max)"
        else
          "Not generated"
        end
      end
      row "Duration" do |video|
        video.duration_human
      end
      row "Bitrate" do |video|
        video.bitrate_human
      end
      row :effective_datetime do |video|
        if video.effective_datetime
          content_tag :div, video.effective_datetime.strftime("%Y-%m-%d %H:%M:%S"), style: "font-weight: bold;"
        else
          content_tag :div, "No date available", style: "color: #cc0000; font-weight: bold;"
        end
      end
      row "Storage State" do |video|
        case video.medium.aasm.current_state
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
      row "Event" do |video|
        if video.medium.event
          link_to video.medium.event.title, family_event_path(video.medium.event), style: "font-weight: bold;"
        else
          content_tag :div, "Not in an event", style: "color: #999;"
        end
      end
      row "Subevent" do |video|
        if video.medium.subevent
          link_to video.medium.subevent.hierarchy_path, family_subevent_path(video.medium.subevent), style: "font-weight: bold;"
        else
          content_tag :div, "Not in a subevent", style: "color: #999;"
        end
      end
      row :user
      row :uploaded_by
      row :camera_make
      row :camera_model
      row :md5_hash
      row :created_at
      row :updated_at
    end

    panel "Metadata" do
      if video.metadata.present?
        div do
          h4 "Formatted Metadata"
          pre JsonFormatterService.pretty_format(video.metadata), 
              style: "background: #f8f8f8; padding: 15px; border-radius: 5px; overflow-x: auto; font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace; font-size: 12px; line-height: 1.4; border: 1px solid #e0e0e0; white-space: pre-wrap;"
        end
      else
        "No metadata available"
      end
    end
  end

  # Form configuration
  form do |f|
    f.inputs "Video Details" do
      f.input :title
      f.input :description
    end

    f.inputs "Dimensions" do
      f.input :width
      f.input :height
    end

    f.inputs "Metadata" do
      f.input :camera_make
      f.input :camera_model
      f.input :duration
      f.input :bitrate
    end

    f.actions
  end

  # Edit a video version (placeholder)
  member_action :edit_version, method: :get do
    video = resource
    medium = video.medium
    version_filename = params[:filename]
    
    unless version_filename.present?
      redirect_to family_medium_path(medium), alert: "No version filename provided"
      return
    end
    
    unless medium.version_exists?(version_filename)
      redirect_to family_medium_path(medium), alert: "Version file not found"
      return
    end
    
    @video = video
    @medium = medium
    @version_filename = version_filename
    
    render 'edit_version_video', layout: 'application'
  end

  # Update a video version (placeholder)
  member_action :update_version, method: :post do
    render json: { success: false, message: "Video editing not yet implemented" }, status: :not_implemented
  end

end

