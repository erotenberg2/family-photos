ActiveAdmin.register Photo, namespace: :family do


  # Add custom action button to index page  
  action_item :import_photos, only: :index do
    link_to 'Import Photos', '#', 
            class: 'btn btn-primary', 
            onclick: 'openImportPopup(); return false;',
            'data-import-popup-url': import_media_popup_family_media_path
  end

  # Permitted parameters (Photo-specific attributes only)
  permit_params :title, :description, :width, :height, :exif_data, :thumbnail_path, 
                :thumbnail_width, :thumbnail_height, :preview_path, :preview_width, 
                :preview_height, :latitude, :longitude, :camera_make, :camera_model

  # Index page configuration
  index do
    # Include the family import JavaScript
    content_for :head do
      javascript_include_tag 'family_import'
    end

    selectable_column
    
    column "Thumbnail", sortable: false do |photo|
      link_to family_photo_path(photo) do
        if photo.thumbnail_path && File.exist?(photo.thumbnail_path)
          image_tag("data:image/jpg;base64,#{Base64.encode64(File.read(photo.thumbnail_path))}", 
                    style: "max-width: 60px; max-height: 60px; object-fit: cover; border-radius: 4px; cursor: pointer; transition: transform 0.2s ease; display: block;",
                    alt: photo.title || photo.original_filename,
                    onmouseover: "this.style.transform='scale(1.05)'",
                    onmouseout: "this.style.transform='scale(1)'")
        else
          # Show placeholder for unprocessed photos
          content_tag :div, "📷", style: "width: 60px; height: 60px; background: #f8f9fa; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px; cursor: pointer; border: 2px dashed #dee2e6;"
        end
      end
    end
    
    column "Location", sortable: false do |photo|
      if photo.has_location?
        content_tag :div, "📍", style: "font-size: 16px; text-align: center;", title: "Location available"
      else
        content_tag :div, "", style: "font-size: 16px; text-align: center;"
      end
    end
    column :original_filename
    column :current_filename
    column :user
    column :uploaded_by
    column :effective_datetime do |photo|
      if photo.effective_datetime
        content_tag :div, photo.effective_datetime.strftime("%Y-%m-%d %H:%M"), 
                    title: "Source: #{photo.datetime_source}"
      else
        content_tag :div, "No date", style: "color: #999;"
      end
    end
    column "Size" do |photo|
      if photo.width && photo.height
        "#{photo.width}×#{photo.height}"
      else
        "Unknown"
      end
    end
    column "File Size" do |photo|
      photo.file_size_human
    end
    column "Storage", sortable: false do |photo|
      case photo.medium.aasm.current_state
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
    column :camera_make
    column :camera_model
    column "Location" do |photo|
      if photo.has_location?
        "#{photo.latitude}, #{photo.longitude}"
      else
        "No location"
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
  filter :created_at

  # Show page configuration
  show do
    # Add CSS for hover effects
    content_for :head do
      raw <<~CSS
        <style>
          .photo-thumbnail-link:hover img {
            box-shadow: 0 4px 12px rgba(0,0,0,0.2) !important;
            transform: scale(1.02);
          }
          .photo-thumbnail-link img {
            transition: all 0.3s ease !important;
          }
        </style>
      CSS
    end

    # Photo preview panel
    panel "Photo Preview" do
      if photo.preview_path && File.exist?(photo.preview_path)
        link_to image_tag("data:image/jpg;base64,#{Base64.encode64(File.read(photo.preview_path))}", 
                  style: "max-width: 400px; max-height: 400px; object-fit: contain; border: 1px solid #ddd; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); display: block; margin: 0 auto;",
                  alt: photo.title || photo.original_filename), image_path(photo.medium), target: "_blank"
      elsif photo.thumbnail_path && File.exist?(photo.thumbnail_path)
        link_to image_tag("data:image/jpg;base64,#{Base64.encode64(File.read(photo.thumbnail_path))}", 
                  style: "max-width: 400px; max-height: 400px; object-fit: contain; border: 1px solid #ddd; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); display: block; margin: 0 auto;",
                  alt: photo.title || photo.original_filename), image_path(photo.medium), target: "_blank"
      else
        div "Preview not available (processing pending or failed)", style: "padding: 40px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
      end
    end

    attributes_table do
      row :id
      row :title
      row :description
      row :original_filename
      row :file_path
      row :current_filename
      row :content_type
      row :file_size do |photo|
        photo.file_size_human
      end
      row :dimensions do |photo|
        if photo.width && photo.height
          "#{photo.width} × #{photo.height} pixels"
        else
          "Not available"
        end
      end
      row :thumbnail_dimensions do |photo|
        if photo.thumbnail_width && photo.thumbnail_height
          "#{photo.thumbnail_width} × #{photo.thumbnail_height} pixels (#{Photo::THUMBNAIL_MAX_SIZE}px max)"
        else
          "Not generated"
        end
      end
      row :preview_dimensions do |photo|
        if photo.preview_width && photo.preview_height
          "#{photo.preview_width} × #{photo.preview_height} pixels (#{Photo::PREVIEW_MAX_SIZE}px max)"
        else
          "Not generated"
        end
      end
      row :effective_datetime do |photo|
        if photo.effective_datetime
          content_tag :div, photo.effective_datetime.strftime("%Y-%m-%d %H:%M:%S"), style: "font-weight: bold;"
        else
          content_tag :div, "No date available", style: "color: #cc0000; font-weight: bold;"
        end
      end
      row "Storage State" do |photo|
        case photo.medium.aasm.current_state
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
      row "Event" do |photo|
        if photo.medium.event
          link_to photo.medium.event.title, admin_event_path(photo.medium.event), style: "font-weight: bold;"
        else
          content_tag :div, "Not in an event", style: "color: #999;"
        end
      end
      row "Subevent" do |photo|
        if photo.medium.subevent
          link_to photo.medium.subevent.hierarchy_path, admin_subevent_path(photo.medium.subevent), style: "font-weight: bold;"
        else
          content_tag :div, "Not in a subevent", style: "color: #999;"
        end
      end
      row :user
      row :uploaded_by
      row :camera_make
      row :camera_model
      row :location do |photo|
        if photo.has_location?
          "#{photo.latitude}, #{photo.longitude}"
        else
          "No location data"
        end
      end
      row :md5_hash
      row :created_at
      row :updated_at
      
      row :albums do |photo|
        photo.albums.map(&:title).join(", ")
      end
    end

    panel "EXIF Data" do
      if photo.exif_data.present?
        div do
          h4 "Formatted EXIF Data"
          pre JsonFormatterService.pretty_format(photo.exif_data), 
              style: "background: #f8f8f8; padding: 15px; border-radius: 5px; overflow-x: auto; font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace; font-size: 12px; line-height: 1.4; border: 1px solid #e0e0e0; white-space: pre-wrap;"
        end
        
        div style: "margin-top: 20px;" do
          h4 "EXIF Properties Table"
          table_for photo.exif_data.to_a do
            column("Property") { |item| item[0] }
            column("Value") { |item| item[1] }
          end
        end
      else
        "No EXIF data available"
      end
    end
  end

  # Form configuration
  form do |f|
    f.inputs "Photo Details" do
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
      f.input :latitude
      f.input :longitude
    end

    f.actions
  end

  # Serve version file for display (inline, not download)
  member_action :version_image, method: :get do
    photo = resource
    medium = photo.medium
    filename = params[:filename]
    
    if filename.present?
      versions_folder = medium.versions_folder_path
      file_path = File.join(versions_folder, filename)
      
      if File.exist?(file_path)
        send_file(file_path, 
                  type: medium.content_type, 
                  disposition: 'inline',
                  filename: filename)
      else
        head :not_found
      end
    else
      head :not_found
    end
  end

  # Edit a photo version
  member_action :edit_version, method: :get do
    photo = resource
    medium = photo.medium
    version_filename = params[:filename]
    
    unless version_filename.present?
      redirect_to family_medium_path(medium), alert: "No version filename provided"
      return
    end
    
    unless medium.version_exists?(version_filename)
      redirect_to family_medium_path(medium), alert: "Version file not found"
      return
    end
    
    @photo = photo
    @medium = medium
    @version_filename = version_filename
    @version_file_path = medium.version_file_path(version_filename)
    @is_primary = medium.read_attribute(:primary) == version_filename
    
    render 'edit_version_photo', layout: 'application'
  end

  # Update a photo version (save edits)
  member_action :update_version, method: :post do
    photo = resource
    medium = photo.medium
    version_filename = params[:filename]
    
    unless version_filename.present?
      redirect_to family_medium_path(medium), alert: "No version filename provided"
      return
    end
    
    unless medium.version_exists?(version_filename)
      redirect_to family_medium_path(medium), alert: "Version file not found"
      return
    end
    
    @photo = photo
    @medium = medium
    @version_filename = version_filename
    @is_primary = medium.read_attribute(:primary) == version_filename
    
    # Process photo edits (cropping, brightness, contrast)
    process_photo_edits(medium, version_filename, params)
  end

  controller do
    private

    def process_photo_edits(medium, version_filename, params)
      version_file_path = medium.version_file_path(version_filename)
      
      unless version_file_path.present? && File.exist?(version_file_path)
        render json: { success: false, error: "Version file not found" }, status: :not_found
        return
      end
      
      begin
        require 'mini_magick'
        
        image = MiniMagick::Image.open(version_file_path)
        original_image = image.dup
        
        # Apply cropping if provided
        if params[:crop_x].present? && params[:crop_y].present? && 
           params[:crop_width].present? && params[:crop_height].present?
          x = params[:crop_x].to_i
          y = params[:crop_y].to_i
          width = params[:crop_width].to_i
          height = params[:crop_height].to_i
          
          if width > 0 && height > 0
            image.crop("#{width}x#{height}+#{x}+#{y}")
            Rails.logger.info "Applied crop: #{width}x#{height} at (#{x},#{y})"
          end
        end
        
        # Apply brightness and contrast adjustments
        # ImageMagick brightness-contrast: brightness ranges from -100 to +100, contrast from -100 to +100
        brightness = params[:brightness].present? ? params[:brightness].to_f : 0
        contrast = params[:contrast].present? ? params[:contrast].to_f : 0
        
        if brightness != 0 || contrast != 0
          # Scale down brightness to ImageMagick: +100 on-screen → +80 in ImageMagick
          # Adjust brightness_scale_factor (0.8 = 80% of slider value) to tune the mapping
          brightness_scale_factor = 0.8
          
          # Apply scaling to positive brightness values only (negative values stay linear)
          imagemagick_brightness = brightness < 0 ? brightness : brightness * brightness_scale_factor
          
          # brightness-contrast: first value is brightness (-100 to +100), second is contrast (-100 to +100)
          image.brightness_contrast("#{imagemagick_brightness}x#{contrast}")
          Rails.logger.info "Applied brightness: #{imagemagick_brightness} (from slider: #{brightness}), contrast: #{contrast}"
        end
        
        # Save the edited image
        image.write(version_file_path)
        
        Rails.logger.info "Saved edited version: #{version_file_path}"
        
        # If this version is primary, regenerate thumbnails and previews
        if medium.read_attribute(:primary) == version_filename
          Rails.logger.info "Version is primary, regenerating thumbnails and previews"
          if medium.mediable&.respond_to?(:generate_thumbnail)
            medium.mediable.generate_thumbnail
          end
        end
        
        # Close popup and refresh parent
        render json: { success: true, message: "Version updated successfully" }, status: :ok
      rescue => e
        Rails.logger.error "Failed to process photo edits: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { success: false, error: e.message }, status: :unprocessable_entity
      end
    end
  end

end
