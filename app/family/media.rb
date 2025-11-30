ActiveAdmin.register Medium, namespace: :family, as: 'Media' do

  # Add custom action buttons to index page
  action_item :import_media, only: :index do
    link_to 'Import Media', '#', 
            class: 'btn btn-primary', 
            onclick: 'openImportPopup(); return false;',
            'data-import-popup-url': import_media_popup_family_media_path
  end


  # Permitted parameters
  permit_params :file_size, :original_filename, :content_type, :md5_hash,
                :datetime_user, :datetime_intrinsic, :datetime_inferred, :medium_type, :uploaded_by_id, :user_id, :descriptive_name

  # Index page configuration
  index do 
    selectable_column
    column :id
    column "Thumbnail", sortable: false do |medium|
      link_to family_medium_path(medium) do
        case medium.medium_type
        when 'photo'
          if medium.mediable&.thumbnail_path && File.exist?(medium.mediable.thumbnail_path)
            # Use small thumbnail (128x128 max)
            image_tag("data:image/jpg;base64,#{Base64.encode64(File.read(medium.mediable.thumbnail_path))}", 
                      style: "max-width: 60px; max-height: 60px; object-fit: cover; border-radius: 4px; cursor: pointer; transition: transform 0.2s ease; display: block;",
                      alt: medium.mediable&.title || medium.original_filename,
                      onmouseover: "this.style.transform='scale(1.05)'",
                      onmouseout: "this.style.transform='scale(1)'")
          else
            # Show placeholder for unprocessed photos (don't load full image)
            content_tag :div, Constants::CAMERA_ICON, style: "width: 60px; height: 60px; background: #f8f9fa; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px; cursor: pointer; border: 2px dashed #dee2e6;"
          end
        when 'audio'
          content_tag :div, Constants::AUDIO_ICON, style: "width: 60px; height: 60px; background: #f0f0f0; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px; cursor: pointer;"
        when 'video'
          if medium.mediable&.thumbnail_path && File.exist?(medium.mediable.thumbnail_path)
            # Use video thumbnail
            image_tag("data:image/jpg;base64,#{Base64.encode64(File.read(medium.mediable.thumbnail_path))}", 
                      style: "max-width: 60px; max-height: 60px; object-fit: cover; border-radius: 4px; cursor: pointer; transition: transform 0.2s ease; display: block;",
                      alt: medium.mediable&.title || medium.original_filename,
                      onmouseover: "this.style.transform='scale(1.05)'",
                      onmouseout: "this.style.transform='scale(1)'")
          else
            # Show placeholder for unprocessed videos
            content_tag :div, Constants::VIDEO_ICON, style: "width: 60px; height: 60px; background: #f8f9fa; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px; cursor: pointer; border: 2px dashed #dee2e6;"
          end
        else
          content_tag :div, Constants::FILE_ICON, style: "width: 60px; height: 60px; background: #f0f0f0; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px; cursor: pointer;"
        end
      end
    end
    
    column "Type", sortable: false do |medium|
      case medium.medium_type
      when 'photo'
        content_tag :div, Constants::CAMERA_ICON, style: "font-size: 20px; text-align: center;", title: "Photo"
      when 'video'
        content_tag :div, Constants::VIDEO_ICON, style: "font-size: 20px; text-align: center;", title: "Video"
      when 'audio'
        content_tag :div, Constants::AUDIO_ICON, style: "font-size: 20px; text-align: center;", title: "Audio"
      else
        content_tag :div, Constants::FILE_ICON, style: "font-size: 20px; text-align: center;", title: "Unknown"
      end
    end
    
    column "Processed", sortable: false do |medium|
      case medium.post_processing_status
      when 'completed'
        if medium.post_processed?
          content_tag :div, "✅", style: "font-size: 18px; text-align: center; color: #28a745;", title: "Processing completed successfully"
        else
          content_tag :div, "❌", style: "font-size: 18px; text-align: center; color: #dc3545;", title: "Processing failed"
        end
      when 'in_progress'
        content_tag :div, "⏳", style: "font-size: 18px; text-align: center; color: #ffc107;", title: "Processing in progress"
      when 'not_started'
        content_tag :div, "⏸️", style: "font-size: 18px; text-align: center; color: #6c757d;", title: "Processing queued"
      else
        content_tag :div, "❓", style: "font-size: 18px; text-align: center; color: #6c757d;", title: "Unknown status"
      end
    end
    
    column "Location", sortable: false do |medium|
      if medium.has_location?
        content_tag :div, "📍", style: "font-size: 16px; text-align: center;", title: "Location available"
      else
        content_tag :div, "", style: "font-size: 16px; text-align: center;"
      end
    end
    
    column :original_filename
    column :current_filename
    column :user
    column :uploaded_by
    column :effective_datetime do |medium|
      if medium.effective_datetime
        content_tag :div, medium.effective_datetime.strftime("%Y-%m-%d %H:%M"), 
                    title: "Source: #{medium.datetime_source}"
      else
        content_tag :div, "No date", style: "color: #999;"
      end
    end
    column "File Size" do |medium|
      medium.file_size_human
    end
    column :content_type
    column "Storage State", sortable: :storage_state do |medium|
      case medium.aasm.current_state
      when :unsorted
        content_tag :div, Constants::UNSORTED_ICON, style: "font-size: 18px; text-align: center;", title: "Unsorted storage"
      when :daily
        content_tag :div, Constants::DAILY_ICON, style: "font-size: 18px; text-align: center;", title: "Daily storage"
      when :event_root
        content_tag :div, Constants::EVENT_ROOT_ICON, style: "font-size: 18px; text-align: center;", title: "Event storage"
      when :subevent_level1
        content_tag :div, Constants::SUBEVENT_LEVEL1_ICON, style: "font-size: 18px; text-align: center;", title: "Subevent level 1 storage"
      when :subevent_level2
        content_tag :div, Constants::SUBEVENT_LEVEL2_ICON, style: "font-size: 18px; text-align: center;", title: "Subevent level 2 storage"
      end
    end
    column "# Versions", sortable: false do |medium|
      version_count = medium.version_list.length
      if version_count > 0
        content_tag :div, version_count, style: "font-weight: bold; color: #0066cc;"
      else
        content_tag :div, "—", style: "color: #999;"
      end
    end
    column "Transitions", sortable: false do |medium|
      generate_transitions_menu(medium)
    end
    
    column :created_at
    
    actions
  end

  # Filters
  filter :medium_type, as: :select, collection: Medium.medium_types.keys.map { |k| [k.humanize, k] }
  filter :content_type, as: :select, collection: proc { Medium.distinct.pluck(:content_type).compact.sort }
  filter :original_filename
  filter :user
  filter :uploaded_by
  filter :datetime_user
  filter :datetime_intrinsic
  filter :datetime_inferred
  filter :storage_state, as: :select, collection: [['Unsorted', 'unsorted'], ['Daily', 'daily'], ['Event Root', 'event_root'], ['Subevent Level 1', 'subevent_level1'], ['Subevent Level 2', 'subevent_level2']]
  filter :created_at

  # Batch actions
  batch_action :destroy, confirm: "Are you sure you want to delete the selected media files?" do |ids|
    deleted_count = 0
    errors = []
    
    ids.each do |id|
      begin
        medium = Medium.find(id)
        medium.destroy
        deleted_count += 1
      rescue => e
        errors << "Failed to delete Medium #{id}: #{e.message}"
      end
    end
    
    if errors.empty?
      redirect_to collection_path, notice: "Successfully deleted #{deleted_count} media files."
    else
      redirect_to collection_path, alert: "Deleted #{deleted_count} files, but encountered #{errors.length} errors: #{errors.join(', ')}"
    end
  end

  batch_action :move_to_unsorted do |ids|
    # Clear any previous batch session data
    session.delete(:batch_target_event_id)
    # Store selected IDs and redirect to validation page
    session[:batch_media_ids] = ids
    session[:batch_transition] = 'move_to_unsorted'
    redirect_to batch_validate_transition_family_media_path
  end

  batch_action :move_to_daily do |ids|
    # Clear any previous batch session data
    session.delete(:batch_target_event_id)
    # Store selected IDs and redirect to validation page
    session[:batch_media_ids] = ids
    session[:batch_transition] = 'move_to_daily'
    redirect_to batch_validate_transition_family_media_path
  end

  batch_action :group_to_new_event do |ids|
    # Clear any previous batch session data
    session.delete(:batch_target_event_id)
    # Store selected IDs and redirect to new event form
    session[:batch_media_ids] = ids
    session[:batch_transition] = 'move_to_event'
    redirect_to new_family_event_path(batch_media_ids: ids.join(','))
  end

  batch_action :add_to_existing_event do |ids|
    # Clear any previous batch session data
    session.delete(:batch_target_event_id)
    # Store selected IDs and redirect to event selection page
    session[:batch_media_ids] = ids
    session[:batch_transition] = 'move_to_event'
    redirect_to batch_select_event_family_media_path
  end

  # Custom actions
  collection_action :new_event_from_media, method: :get do
    @selected_ids = session[:selected_media_ids] || []
    @media = Medium.where(id: @selected_ids)
    @dates = @media.map(&:effective_datetime).compact
    
    if @dates.empty?
      redirect_to collection_path, alert: "No media with valid dates selected. Cannot create event without date information."
      return
    end
    
    @earliest_date = @dates.min.to_date
    @latest_date = @dates.max.to_date
    @suggested_name = "Event #{@earliest_date.strftime('%Y-%m-%d')}"
    if @earliest_date != @latest_date
      @suggested_name += " to #{@latest_date.strftime('%Y-%m-%d')}"
    end
  end
  
  collection_action :create_event_from_media, method: :post do
    selected_ids = session[:selected_media_ids] || []
    
    if selected_ids.empty?
      redirect_to collection_path, alert: "No media selected for event creation."
      return
    end
    
    # Get date range from selected media
    media = Medium.where(id: selected_ids)
    dates = media.map(&:effective_datetime).compact
    
    Rails.logger.info "=== DEBUGGING EVENT DATE RANGE ==="
    Rails.logger.info "Selected media count: #{media.count}"
    Rails.logger.info "Media with effective_datetime: #{dates.count}"
    
    media.each_with_index do |medium, index|
      Rails.logger.info "Medium #{index + 1} (ID: #{medium.id}):"
      Rails.logger.info "  - datetime_user: #{medium.datetime_user}"
      Rails.logger.info "  - datetime_intrinsic: #{medium.datetime_intrinsic}"
      Rails.logger.info "  - datetime_inferred: #{medium.datetime_inferred}"
      Rails.logger.info "  - effective_datetime: #{medium.effective_datetime}"
      Rails.logger.info "  - datetime_source: #{medium.datetime_source}"
    end
    
    if dates.empty?
      redirect_to collection_path, alert: "No media with valid dates selected. Cannot create event without date information."
      return
    end
    
    earliest_date = dates.min.to_date
    latest_date = dates.max.to_date
    
    Rails.logger.info "Date range calculation:"
    Rails.logger.info "  - Earliest date: #{earliest_date}"
    Rails.logger.info "  - Latest date: #{latest_date}"
    Rails.logger.info "=== END DEBUGGING EVENT DATE RANGE ==="
    
    # Create event with user-provided name
    event_params = {
      title: params[:event_title],
      start_date: earliest_date,
      end_date: latest_date,
      description: "Created from #{selected_ids.length} media files",
      created_by: current_user
    }
    
    event = Event.new(event_params)
    
    if event.save
      # Handle single medium transitions via state machine
      if session[:pending_transition].present? && session[:pending_transition_medium_id].present?
        medium = Medium.find(session[:pending_transition_medium_id])
        pending_transition = session[:pending_transition]
        
        # Set the event_id before transitioning
        medium.event_id = event.id
        
        # Execute the state machine transition
        begin
          medium.send("#{pending_transition}!")
          
          # Clear the session
          session[:selected_media_ids] = nil
          session[:pending_transition] = nil
          session[:pending_transition_medium_id] = nil
          
          redirect_to family_event_path(event), notice: "Successfully created event '#{event.title}' and moved media."
        rescue => e
          # Clear the session
          session[:selected_media_ids] = nil
          session[:pending_transition] = nil
          session[:pending_transition_medium_id] = nil
          
          redirect_to family_event_path(event), alert: "Created event but failed to move media: #{e.message}"
        end
      else
        # Batch operation - use FileOrganizationService
        results = FileOrganizationService.move_to_event_storage(selected_ids, event.id)
        
        # Clear the session
        session[:selected_media_ids] = nil
        
        if results[:error_count] == 0
          redirect_to family_event_path(event), notice: "Successfully created event '#{event.title}' and moved #{results[:success_count]} files."
        elsif results[:success_count] > 0
          redirect_to family_event_path(event), 
                      alert: "Created event '#{event.title}' and moved #{results[:success_count]} files, but encountered #{results[:error_count]} errors: #{results[:errors].join(', ')}"
        else
          redirect_to collection_path, alert: "Failed to create event and move files: #{results[:errors].join(', ')}"
        end
      end
    else
      # Show validation errors and let user try again
      @selected_ids = selected_ids
      @media = media
      @dates = dates
      @earliest_date = earliest_date
      @latest_date = latest_date
      @suggested_name = params[:event_title]
      @errors = event.errors.full_messages
      
      render :new_event_from_media
    end
  end
  
  collection_action :add_to_existing_event, method: :get do
    @selected_ids = session[:selected_media_ids_for_existing] || []
    @media = Medium.where(id: @selected_ids)
    @dates = @media.map(&:effective_datetime).compact
    
    if @dates.empty?
      redirect_to collection_path, alert: "No media with valid dates selected. Cannot add to event without date information."
      return
    end
    
    @earliest_date = @dates.min.to_date
    @latest_date = @dates.max.to_date
    @existing_events = Event.order(:title)
  end
  
  collection_action :move_to_existing_event, method: :post do
    selected_ids = session[:selected_media_ids_for_existing] || []
    event_id = params[:event_id]
    
    if selected_ids.empty?
      redirect_to collection_path, alert: "No media selected for event addition."
      return
    end
    
    if event_id.blank?
      redirect_to add_to_existing_event_family_media_path, alert: "Please select an event."
      return
    end
    
    begin
      event = Event.find(event_id)
      
      # Handle single medium transitions via state machine
      if session[:pending_transition].present? && session[:pending_transition_medium_id].present?
        medium = Medium.find(session[:pending_transition_medium_id])
        pending_transition = session[:pending_transition]
        
        # Set the event_id before transitioning
        medium.event_id = event.id
        
        # Execute the state machine transition
        begin
          medium.send("#{pending_transition}!")
          
          # Clear the session
          session[:selected_media_ids_for_existing] = nil
          session[:pending_transition] = nil
          session[:pending_transition_medium_id] = nil
          
          redirect_to family_event_path(event), notice: "Successfully moved media to event '#{event.title}'."
        rescue => e
          # Clear the session
          session[:selected_media_ids_for_existing] = nil
          session[:pending_transition] = nil
          session[:pending_transition_medium_id] = nil
          
          redirect_to family_event_path(event), alert: "Failed to move media to event: #{e.message}"
        end
      else
        # Batch operation - use FileOrganizationService
        results = FileOrganizationService.move_to_event_storage(selected_ids, event.id)
        
        # Clear the session
        session[:selected_media_ids_for_existing] = nil
        
        if results[:error_count] == 0
          redirect_to family_event_path(event), notice: "Successfully added #{results[:success_count]} files to event '#{event.title}'."
        elsif results[:success_count] > 0
          redirect_to family_event_path(event), 
                      alert: "Added #{results[:success_count]} files to event '#{event.title}', but encountered #{results[:error_count]} errors: #{results[:errors].join(', ')}"
        else
          redirect_to collection_path, alert: "Failed to add files to event: #{results[:errors].join(', ')}"
        end
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to add_to_existing_event_family_media_path, alert: "Selected event not found."
    end
  end

  # Show page configuration
  show do
    # Add CSS for hover effects
    content_for :head do
      raw <<~CSS
        <style>
          .media-preview-link:hover img, .media-preview-link:hover video {
            box-shadow: 0 4px 12px rgba(0,0,0,0.2) !important;
            transform: scale(1.02);
          }
          .media-preview-link img, .media-preview-link video {
            transition: all 0.3s ease !important;
          }
        </style>
      CSS
    end

    # Media preview panel
    panel "Media Preview" do
      case resource.medium_type
      when 'photo'
        if resource.mediable&.preview_path && File.exist?(resource.mediable.preview_path)
          link_to image_tag("data:image/jpg;base64,#{Base64.encode64(File.read(resource.mediable.preview_path))}", 
                    style: "max-width: 400px; max-height: 400px; object-fit: contain; border: 1px solid #ddd; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); display: block; margin: 0 auto;",
                    alt: resource.mediable&.title || resource.original_filename), image_path(resource), target: "_blank"
        else
          div "Photo preview not available", style: "padding: 40px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
        end
      when 'audio'
        if resource.file_exists?
          audio_tag image_path(resource), controls: true, style: "width: 100%; max-width: 400px; margin: 0 auto; display: block;"
        else
          div "Audio file not found", style: "padding: 40px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
        end
      when 'video' 
        if resource.file_exists?
          # Check if video format is supported by browsers
          unsupported_formats = ['video/x-ms-wmv', 'video/wmv', 'video/x-ms-asf', 'video/flv', 'video/x-flv']
          
          if unsupported_formats.include?(resource.content_type)
            div do
              para "⚠️ This video format (#{resource.content_type}) may not play in all browsers.", 
                   style: "color: #856404; background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 4px; margin-bottom: 15px;"
              
              li ("Download the video file to play it: " +
                  link_to("Download #{resource.original_filename}", 
                          image_path(resource),
                          download: resource.original_filename,
                          style: "font-weight: bold; color: #007bff;")).html_safe
            end
          end
          
          video_tag image_path(resource), controls: true, style: "max-width: 400px; max-height: 400px; margin: 0 auto; display: block;"
        else
          div "Video file not found", style: "padding: 40px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
        end
      else
        div "Preview not available for this media type", style: "padding: 40px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
      end
    end


    
    # Versions panel
    panel "Versions" do
      # Action buttons at top
      div style: "margin-bottom: 20px; padding: 10px; background: #f9f9f9; border-radius: 5px; border: 1px solid #ddd;" do
        div style: "display: inline-block; margin-right: 10px;" do
          link_to "Create in-place version", "#", 
                  class: 'button',
                  onclick: "document.getElementById('create-inplace-version-form').style.display = 'block'; return false;"
        end
        div style: "display: inline-block;" do
          link_to "Upload new version", "#", 
                  class: 'button',
                  onclick: "document.getElementById('upload-new-version-form').style.display = 'block'; return false;"
        end
      end
      
      # Create in-place version dialog
      div id: "create-inplace-version-form", style: "display: none; margin-bottom: 20px; padding: 15px; background: #f9f9f9; border-radius: 5px; border: 1px solid #ddd;" do
        raw <<-HTML
          <form action="#{create_inplace_version_family_medium_path(resource)}" method="post" style="margin: 0;">
            <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
            <label for="inplace-description" style="display: block; margin-bottom: 5px; font-weight: bold;">Description:</label>
            <input type="text" id="inplace-description" name="description" required placeholder="e.g., Color corrected, Cropped, etc." style="width: 100%; padding: 8px; margin-bottom: 10px; box-sizing: border-box;">
            <button type="submit" class="button" style="margin-right: 10px;">Create Version</button>
            <button type="button" class="button" style="background: #999;" onclick="document.getElementById('create-inplace-version-form').style.display = 'none'; return false;">Cancel</button>
          </form>
        HTML
      end
      
      # Upload new version dialog
      div id: "upload-new-version-form", style: "display: none; margin-bottom: 20px; padding: 15px; background: #f9f9f9; border-radius: 5px; border: 1px solid #ddd;" do
        raw <<-HTML
          <form action="#{upload_new_version_family_medium_path(resource)}" method="post" enctype="multipart/form-data" style="margin: 0;">
            <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
            <label for="version-file" style="display: block; margin-bottom: 5px; font-weight: bold;">File:</label>
            <input type="file" id="version-file" name="version_file" required style="width: 100%; padding: 8px; margin-bottom: 10px; box-sizing: border-box;">
            <label for="upload-description" style="display: block; margin-bottom: 5px; font-weight: bold;">Description:</label>
            <input type="text" id="upload-description" name="description" required placeholder="e.g., Edited version, Final, etc." style="width: 100%; padding: 8px; margin-bottom: 10px; box-sizing: border-box;">
            <button type="submit" class="button" style="margin-right: 10px;">Upload Version</button>
            <button type="button" class="button" style="background: #999;" onclick="document.getElementById('upload-new-version-form').style.display = 'none'; return false;">Cancel</button>
          </form>
        HTML
      end
      
      # Root version table (always shown, single row)
      root_is_primary = resource.read_attribute(:primary).nil?
      table_for [resource], class: "root-version-table" do
        column "Primary" do |medium|
          if root_is_primary
            raw '<span style="color: #28a745; font-size: 18px; font-weight: bold;">✓</span>'
          else
            "—"
          end
        end
        column "Root version" do |medium|
          medium.descriptive_name.presence || File.basename(medium.current_filename, File.extname(medium.current_filename))
        end
        column "Description" do |medium|
          medium.read_attribute(:description).presence || "Original file"
        end
        column "effective_datetime" do |medium|
          if medium.effective_datetime
            medium.effective_datetime.strftime("%Y-%m-%d %H:%M:%S")
          else
            "—"
          end
        end
        column "Actions" do |medium|
          unless root_is_primary
            link_to("Make primary", make_primary_family_medium_path(medium, version_filename: nil),
              method: :post,
              confirm: "Set this root file as the primary version?",
              style: "margin-right: 10px;")
          end
        end
      end
      
      versions_list = resource.version_list.sort_by { |v| v['created_at'] }
      
      if versions_list.any?
        table_for versions_list do
          column "Primary" do |version|
            version_filename = version['filename']
            is_primary = resource.read_attribute(:primary) == version_filename
            if is_primary
              raw '<span style="color: #28a745; font-size: 18px; font-weight: bold;">✓</span>'
            else
              "—"
            end
          end
          column "Version" do |version|
            File.basename(version['filename'], File.extname(version['filename']))
          end
          column "Description" do |version|
            version['description']
          end
          column "Parent" do |version|
            parent_filename = version['parent']
            if parent_filename.present?
              File.basename(parent_filename, File.extname(parent_filename))
            else
              "—"
            end
          end
          column "Created" do |version|
            if version['created_at']
              Time.parse(version['created_at']).strftime("%Y-%m-%d %H:%M")
            else
              "—"
            end
          end
          column "Actions" do |version|
            version_filename = version['filename']
            is_primary = resource.read_attribute(:primary) == version_filename
            
            actions = []
            if resource.version_exists?(version_filename)
              actions << link_to("Download", version_family_medium_path(resource, filename: version_filename),
                style: "margin-right: 10px;")
              
              # Edit action - opens in popup
              edit_url = edit_version_family_medium_path(resource, filename: version_filename)
              actions << link_to("Edit", "#",
                onclick: "window.open('#{edit_url}', 'editVersion', 'width=900,height=700,scrollbars=yes,resizable=yes'); return false;",
                style: "margin-right: 10px;")
              
              unless is_primary
                actions << link_to("Make primary", make_primary_family_medium_path(resource, version_filename: version_filename),
                  method: :post,
                  confirm: "Set this version as the primary version?",
                  style: "margin-right: 10px;")
              end
              
              # Delete action
              children_count = resource.version_children(version_filename).length
              confirm_msg = if children_count > 0
                "Are you sure you want to delete this version? #{children_count} child version(s) will inherit this version's parent."
              else
                "Are you sure you want to delete this version?"
              end
              actions << link_to("Delete", delete_version_family_medium_path(resource, filename: version_filename),
                data: { method: :delete, confirm: confirm_msg },
                style: "color: red; margin-left: 10px;")
            else
              actions << span("File not found", style: "color: #999;")
            end
            
            raw actions.join(" ")
          end
        end
      else
        div "No versions", style: "padding: 20px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
      end
    end
    # Attachments panel
    panel "Attachments" do
      attachments_path = resource.attachments_folder_path
      if attachments_path && Dir.exist?(attachments_path)
        # List files in the attachments subfolder
        files = Dir.glob(File.join(attachments_path, '*')).select { |f| File.file?(f) }
        
        if files.any?
          table_for files do
            column "Filename" do |file_path|
              File.basename(file_path)
            end
            column "Size" do |file_path|
              size = File.size(file_path)
              "#{(size / 1024.0).round(2)} KB"
            end
            column "Actions" do |file_path|
              link_to("Download", attachment_family_medium_path(resource, filename: File.basename(file_path)),
                style: "margin-right: 10px;") +
              link_to("Delete", delete_attachment_family_medium_path(resource, filename: File.basename(file_path)),
                method: :delete,
                confirm: "Are you sure you want to delete this attachment?",
                style: "color: red;")
            end
          end
        else
          div "No attachments", style: "padding: 20px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
        end
      else
        div "No attachments", style: "padding: 20px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
      end
      
      div do
        link_to "Add Attachment", "#", 
                class: 'button',
                onclick: "document.getElementById('attachment-upload-form').style.display = 'block'; return false;",
                style: "margin-top: 15px;"
      end
      
      div id: "attachment-upload-form", style: "display: none; margin-top: 15px; padding: 15px; background: #f9f9f9; border-radius: 5px; border: 1px solid #ddd;" do
        raw <<-HTML
          <form action="#{add_attachment_family_medium_path(resource)}" method="post" enctype="multipart/form-data" style="margin: 0;">
            <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
            <input type="file" name="attachment" required style="margin-bottom: 10px; display: block;">
            <button type="submit" class="button" style="margin-right: 10px;">Upload</button>
            <button type="button" class="button" style="background: #999;" onclick="document.getElementById('attachment-upload-form').style.display = 'none'; return false;">Cancel</button>
          </form>
        HTML
      end
    end
    attributes_table do
      row :id
      row "Type" do |resource|
        status_tag resource.medium_type.humanize, class: "#{resource.medium_type}_type"
      end
      row "Title" do |resource|
        resource.mediable&.title || "Untitled"
      end
      row "Description" do |resource|
        resource.read_attribute(:description).presence || "No description"
      end
      row :original_filename
      row "Storage Path" do |resource|
        resource.computed_directory_path || "Not set"
      end
      row :current_filename
      row :content_type
      row :file_size do |resource|
        resource.file_size_human
      end
      row :datetime_user do |medium|
        if medium.datetime_user
          content_tag :div, medium.datetime_user.strftime("%Y-%m-%d %H:%M:%S"), style: "color: #0066cc;"
        else
          content_tag :div, "Not set", style: "color: #999;"
        end
      end
      row :datetime_intrinsic do |medium|
        if medium.datetime_intrinsic
          content_tag :div, medium.datetime_intrinsic.strftime("%Y-%m-%d %H:%M:%S"), style: "color: #009900;"
        else
          content_tag :div, "No EXIF data", style: "color: #999;"
        end
      end
      row :datetime_inferred do |medium|
        if medium.datetime_inferred
          content_tag :div, medium.datetime_inferred.strftime("%Y-%m-%d %H:%M:%S"), style: "color: #ff6600;"
        else
          content_tag :div, "Not needed", style: "color: #999;"
        end
      end
      row :effective_datetime do |medium|
        if medium.effective_datetime
          content_tag :div, medium.effective_datetime.strftime("%Y-%m-%d %H:%M:%S"), style: "font-weight: bold;"
        else
          content_tag :div, "No date available", style: "color: #cc0000; font-weight: bold;"
        end
      end
      row :datetime_source_last_modified
      row "Storage State" do |medium|
        case medium.aasm.current_state
        when :unsorted
          content_tag :div, "#{Constants::UNSORTED_ICON} Unsorted Storage", style: "font-size: 16px;", title: "Stored in unsorted organization structure"
        when :daily
          content_tag :div, "#{Constants::DAILY_ICON} Daily Storage", style: "font-size: 16px;", title: "Stored in daily organization structure"
        when :event_root
          content_tag :div, "#{Constants::EVENT_ROOT_ICON} Event Root Storage", style: "font-size: 16px;", title: "Stored in event organization structure"
        when :subevent_level1
          content_tag :div, "#{Constants::SUBEVENT_LEVEL1_ICON} Subevent Level 1", style: "font-size: 16px;", title: "Stored in subevent level 1"
        when :subevent_level2
          content_tag :div, "#{Constants::SUBEVENT_LEVEL2_ICON} Subevent Level 2", style: "font-size: 16px;", title: "Stored in subevent level 2"
        end
      end
      row :storage_state
      row "Event" do |medium|
        if medium.event
          link_to medium.event.title, admin_event_path(medium.event), style: "font-weight: bold;"
        else
          content_tag :div, "Not in an event", style: "color: #999;"
        end
      end
      row "Subevent" do |medium|
        if medium.subevent
          link_to medium.subevent.hierarchy_path, admin_subevent_path(medium.subevent), style: "font-weight: bold;"
        else
          content_tag :div, "Not in a subevent", style: "color: #999;"
        end
      end
      row :user
      row :uploaded_by
      row :md5_hash
      row :created_at
      row :updated_at
      row :processing_started_at
      row :processing_completed_at
      row "Processing Duration" do |resource|
        if resource.post_processing_duration
          "#{(resource.post_processing_duration * 1000).round}ms"
        else
          "—"
        end
      end
      row "Processing Status" do |resource|
        case resource.post_processing_status
        when 'completed'
          status_tag "Completed", class: :ok
        when 'in_progress'
          status_tag "In Progress", class: :warning
        when 'not_started'
          status_tag "Not Started", class: :no
        else
          status_tag "Unknown", class: :error
        end
      end
    end

    # Show type-specific details
    if resource.mediable
      case resource.medium_type
      when 'photo'
        panel "Photo Details" do
          attributes_table_for resource.mediable do
            row :camera_make
            row :camera_model
            row :location do |photo|
              if photo.latitude && photo.longitude
                "#{photo.latitude}, #{photo.longitude}"
              else
                "No location data"
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
          end

          if resource.mediable.exif_data.present?
            h4 "EXIF Data"
            pre JsonFormatterService.pretty_format(resource.mediable.exif_data), 
                style: "background: #f8f8f8; padding: 15px; border-radius: 5px; overflow-x: auto; font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace; font-size: 12px; line-height: 1.4; border: 1px solid #e0e0e0; white-space: pre-wrap;"
          end
        end
      when 'audio'
        panel "Audio Details" do
          attributes_table_for resource.mediable do
            row :artist
            row :album
            row :album_artist
            row :genre
            row :year
            row :track
            row :composer
            row :publisher
            row :duration do |audio|
              audio.duration_human
            end
            row :bitrate do |audio|
              audio.bitrate_human
            end
            row :bpm
            row :compilation
          end
        end
      when 'video'
        panel "Video Details" do
          attributes_table_for resource.mediable do
            row :width
            row :height
            row :dimensions do |video|
              if video.width && video.height
                "#{video.width} × #{video.height} pixels"
              else
                "Not available"
              end
            end
            row :duration do |video|
              video.duration_human
            end
            row :bitrate do |video|
              video.bitrate_human
            end
            row :camera_make
            row :camera_model
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
          end

          if resource.mediable.metadata.present?
            h4 "Metadata"
            pre JsonFormatterService.pretty_format(resource.mediable.metadata), 
                style: "background: #f8f8f8; padding: 15px; border-radius: 5px; overflow-x: auto; font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace; font-size: 12px; line-height: 1.4; border: 1px solid #e0e0e0; white-space: pre-wrap;"
          end
        end
      end
    end

  end

  # Form for editing media
  form do |f|
    f.inputs "Media Information" do
      f.input :original_filename, input_html: { readonly: true }
      f.input :current_filename, input_html: { readonly: true }
      f.input :content_type, input_html: { readonly: true }
      f.input :file_size, input_html: { readonly: true }
    end

    f.inputs "Edit Filename" do
      f.input :descriptive_name, 
              label: "Descriptive Name",
              hint: "Enter a descriptive name for this file. The timestamp and extension will be preserved automatically.",
              placeholder: "Enter descriptive name"
    end

    f.actions
  end

  # Attachment management actions
  member_action :add_attachment, method: :post do
    medium = resource
    file = params[:attachment]
    
    if file.present?
      attachments_folder = medium.attachments_folder_path
      
      # Create aux folder and attachments subfolder if they don't exist
      unless Dir.exist?(attachments_folder)
        FileUtils.mkdir_p(attachments_folder)
      end
      
      # Save the uploaded file to the attachments folder
      file_path = File.join(attachments_folder, file.original_filename)
      File.binwrite(file_path, file.read)
      
      redirect_to family_medium_path(medium), notice: "Attachment added successfully"
    else
      redirect_to family_medium_path(medium), alert: "No file provided"
    end
  end

  member_action :delete_attachment, method: :delete do
    medium = resource
    filename = params[:filename]
    
    if filename.present?
      attachments_folder = medium.attachments_folder_path
      file_path = File.join(attachments_folder, filename)
      
      if File.exist?(file_path)
        File.delete(file_path)
        redirect_to family_medium_path(medium), notice: "Attachment deleted successfully"
      else
        redirect_to family_medium_path(medium), alert: "File not found"
      end
    else
      redirect_to family_medium_path(medium), alert: "No filename provided"
    end
  end

  member_action :attachment, method: :get do
    medium = resource
    filename = params[:filename]
    
    if filename.present?
      attachments_folder = medium.attachments_folder_path
      file_path = File.join(attachments_folder, filename)
      
      if File.exist?(file_path)
        send_file(file_path, disposition: 'attachment')
      else
        redirect_to family_medium_path(medium), alert: "File not found"
      end
    else
      redirect_to family_medium_path(medium), alert: "No filename provided"
    end
  end

  member_action :version, method: :get do
    medium = resource
    filename = params[:filename]
    
    if filename.present?
      versions_folder = medium.versions_folder_path
      file_path = File.join(versions_folder, filename)
      
      if File.exist?(file_path)
        send_file(file_path, disposition: 'attachment')
      else
        redirect_to family_medium_path(medium), alert: "Version file not found"
      end
    else
      redirect_to family_medium_path(medium), alert: "No filename provided"
    end
  end

  # Serve version file for display (inline, not download)
  member_action :version_image, method: :get do
    medium = resource
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

  # Edit a version
  member_action :edit_version, method: :get do
    medium = resource
    version_filename = params[:filename]
    
    unless version_filename.present?
      redirect_to family_medium_path(medium), alert: "No version filename provided"
      return
    end
    
    unless medium.version_exists?(version_filename)
      redirect_to family_medium_path(medium), alert: "Version file not found"
      return
    end
    
    @medium = medium
    @version_filename = version_filename
    @version_file_path = medium.version_file_path(version_filename)
    @is_primary = medium.read_attribute(:primary) == version_filename
    
    # Render different views based on medium type
    case medium.medium_type
    when 'photo'
      render 'edit_version_photo', layout: 'application'
    when 'video'
      render 'edit_version_video', layout: 'application'
    when 'audio'
      render 'edit_version_audio', layout: 'application'
    else
      redirect_to family_medium_path(medium), alert: "Unknown media type"
    end
  end

  # Update a version (save edits)
  member_action :update_version, method: :post do
    medium = resource
    version_filename = params[:filename]
    
    unless version_filename.present?
      redirect_to family_medium_path(medium), alert: "No version filename provided"
      return
    end
    
    unless medium.version_exists?(version_filename)
      redirect_to family_medium_path(medium), alert: "Version file not found"
      return
    end
    
    @medium = medium
    @version_filename = version_filename
    @is_primary = medium.read_attribute(:primary) == version_filename
    
    case medium.medium_type
    when 'photo'
      # Process photo edits (cropping, brightness, contrast)
      process_photo_edits(medium, version_filename, params)
      return  # process_photo_edits handles the response
    when 'video'
      # Placeholder for video
      render json: { success: false, message: "Video editing not yet implemented" }, status: :not_implemented
    when 'audio'
      # Placeholder for audio
      render json: { success: false, message: "Audio editing not yet implemented" }, status: :not_implemented
    else
      render json: { success: false, message: "Unknown media type" }, status: :bad_request
    end
  end

  # Delete a version
  member_action :delete_version, method: :delete do
    medium = resource
    version_filename = params[:filename]
    
    unless version_filename.present?
      redirect_to family_medium_path(medium), alert: "No version filename provided"
      return
    end
    
    # Find the version in the versions list
    version_list = medium.version_list
    version_to_delete = version_list.find { |v| v['filename'] == version_filename }
    
    unless version_to_delete
      redirect_to family_medium_path(medium), alert: "Version not found in versions list"
      return
    end
    
    begin
      # Get children of this version
      children = medium.version_children(version_filename)
      parent_of_deleted = version_to_delete['parent']  # What the deleted version's parent is
      
      # Check if this version is primary
      is_primary = medium.read_attribute(:primary) == version_filename
      
      # Update children to inherit the deleted version's parent and remove the deleted version
      updated_versions = version_list.map do |v|
        if v['filename'] == version_filename
          nil  # Mark for deletion
        elsif v['parent'] == version_filename
          # This is a child of the deleted version - update its parent
          v.merge('parent' => parent_of_deleted)
        else
          v
        end
      end.compact  # Remove nil entries (the deleted version)
      
      # Update both versions and primary in a single transaction
      update_hash = { versions: updated_versions }
      update_hash[:primary] = nil if is_primary
      
      medium.update!(update_hash)
      
      if children.any?
        Rails.logger.info "Updated #{children.length} child version(s) to inherit parent: #{parent_of_deleted || 'root'}"
      end
      
      if is_primary
        Rails.logger.info "Reset primary to null (deleted version was primary)"
      end
      
      # Delete the version file from disk
      version_file_path = medium.version_file_path(version_filename)
      if version_file_path.present? && File.exist?(version_file_path)
        File.delete(version_file_path)
        Rails.logger.info "Deleted version file: #{version_file_path}"
      end
      
      # Sync versions.json happens automatically via after_save callback
      # If primary was reset and this was a photo/video, regenerate thumbnails
      if is_primary && (medium.medium_type == 'photo' || medium.medium_type == 'video')
        if medium.mediable&.respond_to?(:generate_thumbnail)
          medium.mediable.generate_thumbnail
          Rails.logger.info "Regenerated thumbnails/previews after primary version deletion"
        end
      end
      
      redirect_to family_medium_path(medium), notice: "Version deleted successfully#{children.any? ? " (#{children.length} child version(s) updated)" : ""}"
    rescue => e
      Rails.logger.error "Failed to delete version: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to family_medium_path(medium), alert: "Error deleting version: #{e.message}"
    end
  end

  # Set a version (or root) as the primary version
  member_action :make_primary, method: :post do
    medium = resource
    version_filename = params[:version_filename]
    
    begin
      if version_filename.blank?
        # Setting root as primary (clear primary column)
        medium.update!(primary: nil)
        Rails.logger.info "Set root file as primary for medium #{medium.id}"
        redirect_to family_medium_path(medium), notice: "Root file set as primary version"
      else
        # Verify version exists
        unless medium.version_exists?(version_filename)
          redirect_to family_medium_path(medium), alert: "Version file not found"
          return
        end
        
        # Verify version is in the versions list
        unless medium.version_list.any? { |v| v['filename'] == version_filename }
          redirect_to family_medium_path(medium), alert: "Version not found in versions list"
          return
        end
        
        # Set this version as primary
        medium.update!(primary: version_filename)
        Rails.logger.info "Set version #{version_filename} as primary for medium #{medium.id}"
        redirect_to family_medium_path(medium), notice: "Version set as primary"
      end
    rescue => e
      Rails.logger.error "Failed to set primary version: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to family_medium_path(medium), alert: "Error setting primary version: #{e.message}"
    end
  end

  # Create a new version by copying the current primary file
  member_action :create_inplace_version, method: :post do
    medium = resource
    description = params[:description]&.strip
    
    unless description.present?
      redirect_to family_medium_path(medium), alert: "Description is required"
      return
    end
    
    begin
      # Verify medium has a filename
      unless medium.current_filename.present?
        redirect_to family_medium_path(medium), alert: "Medium does not have a filename. Cannot create version."
        return
      end
      
      # Get the primary file path (or main file if primary is null)
      source_path = medium.source_file_path_for_thumbnails || medium.full_file_path
      
      unless source_path.present? && File.exist?(source_path)
        Rails.logger.error "Source file not found for medium #{medium.id}: #{source_path}"
        redirect_to family_medium_path(medium), alert: "Source file not found. Cannot create version."
        return
      end
      
      Rails.logger.info "Creating in-place version from: #{source_path}"
      
      # Create a temporary copy of the file
      require 'tempfile'
      temp_file = Tempfile.new([File.basename(source_path, File.extname(source_path)), File.extname(source_path)])
      temp_path = temp_file.path
      FileUtils.cp(source_path, temp_path)
      temp_file.close  # Close file handle but keep file on disk (don't use close! which unlinks)
      Rails.logger.info "Created temp file: #{temp_path}, exists: #{File.exist?(temp_path)}"
      
      # Verify temp file exists before proceeding
      unless File.exist?(temp_path)
        redirect_to family_medium_path(medium), alert: "Failed to create temporary file copy"
        return
      end
      
      begin
        # New version should be a child of the current primary version
        # If primary is a version filename, use that; if primary is nil (root is primary), use nil
        current_primary = medium.read_attribute(:primary)
        parent_version = current_primary  # Will be version filename or nil (for root)
        Rails.logger.info "Creating version as child of: #{parent_version || 'root (primary)'}"
        Rails.logger.info "Calling add_version with temp_path: #{temp_path} (exists: #{File.exist?(temp_path)})"
        success = medium.add_version(temp_path, description, parent: parent_version)
        
        if success
          redirect_to family_medium_path(medium), notice: "Version created successfully"
          return
        else
          # Clean up temp file if add_version failed
          File.delete(temp_path) if File.exist?(temp_path)
          Rails.logger.error "add_version returned false for medium #{medium.id}"
          redirect_to family_medium_path(medium), alert: "Failed to create version. Check logs for details."
          return
        end
      rescue => add_error
        # Clean up temp file on error
        File.delete(temp_path) if File.exist?(temp_path)
        raise add_error
      end
    rescue => e
      Rails.logger.error "Failed to create in-place version: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to family_medium_path(medium), alert: "Error creating version: #{e.message}"
    end
  end

  # Upload a new file as a version
  member_action :upload_new_version, method: :post do
    medium = resource
    uploaded_file = params[:version_file]
    description = params[:description]&.strip
    
    unless uploaded_file.present?
      redirect_to family_medium_path(medium), alert: "No file provided"
      return
    end
    
    unless description.present?
      redirect_to family_medium_path(medium), alert: "Description is required"
      return
    end
    
    begin
      # Save uploaded file to temporary location
      require 'tempfile'
      temp_file = Tempfile.new([File.basename(uploaded_file.original_filename, File.extname(uploaded_file.original_filename)), File.extname(uploaded_file.original_filename)])
      temp_path = temp_file.path
      File.binwrite(temp_path, uploaded_file.read)
      temp_file.close  # Close file handle but keep file on disk (don't use close! which unlinks)
      Rails.logger.info "Created temp file: #{temp_path}, exists: #{File.exist?(temp_path)}"
      
      begin
        # New version should be a child of the current primary version
        # If primary is a version filename, use that; if primary is nil (root is primary), use nil
        current_primary = medium.read_attribute(:primary)
        parent_version = current_primary  # Will be version filename or nil (for root)
        Rails.logger.info "Creating version as child of: #{parent_version || 'root (primary)'}"
        success = medium.add_version(temp_path, description, parent: parent_version)
        
        if success
          redirect_to family_medium_path(medium), notice: "Version uploaded successfully"
          return
        else
          # Clean up temp file if add_version failed
          File.delete(temp_path) if File.exist?(temp_path)
          redirect_to family_medium_path(medium), alert: "Failed to upload version"
          return
        end
      rescue => add_error
        # Clean up temp file on error
        File.delete(temp_path) if File.exist?(temp_path)
        raise add_error
      end
    rescue => e
      Rails.logger.error "Failed to upload new version: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to family_medium_path(medium), alert: "Error uploading version: #{e.message}"
    end
  end

  # Handle form submission for filename editing
  controller do
    helper MediumTransitionsHelper
    
    def update
      if params[:medium] && params[:medium][:descriptive_name].present?
        new_descriptive_name = params[:medium][:descriptive_name].strip
        
        if new_descriptive_name.blank?
          redirect_to edit_family_medium_path(resource), alert: "Descriptive name cannot be blank."
          return
        end
        
        # Set descriptive_name on the resource to trigger validation
        resource.descriptive_name = new_descriptive_name
        
        # Validate descriptive_name before generating filename
        unless resource.valid?
          if resource.errors[:descriptive_name].any?
            redirect_to edit_family_medium_path(resource), alert: resource.errors[:descriptive_name].first
            return
          end
        end
        
        begin
          # Generate new filename using datetime priority scheme
          new_filename = generate_filename_from_datetime_and_descriptive_name(resource, new_descriptive_name)
          
          # Check if the new filename would conflict with existing files (excluding current record)
          if Medium.where("LOWER(current_filename) = ?", new_filename.downcase).where.not(id: resource.id).exists?
            redirect_to edit_family_medium_path(resource), alert: "A file with this name already exists."
            return
          end
          
          # Also check if file exists on disk at the destination
          dir_path = resource.computed_directory_path
          if dir_path.present?
            new_full_path = File.join(dir_path, new_filename)
            if File.exist?(new_full_path)
              redirect_to edit_family_medium_path(resource), alert: "A file with this name already exists on disk."
              return
            end
          end
          
          # Update the current_filename, which will trigger the callback to rename the file
          resource.update!(current_filename: new_filename)
        
          redirect_to family_medium_path(resource), notice: "Filename updated successfully to '#{new_filename}'."
          return
        rescue => e
          redirect_to edit_family_medium_path(resource), alert: "Error updating filename: #{e.message}"
          return
        end
      end
      
      # If no descriptive_name provided, do normal update
      super
    end

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

    def generate_filename_from_datetime_and_descriptive_name(medium, descriptive_name)
      # Extract the timestamp from the current filename (part before the first dash)
      current_filename = medium.current_filename
      
      # Get file extension from current filename
      extension = File.extname(current_filename)
      
      # Get the name without extension
      name_without_ext = File.basename(current_filename, extension)
      
      # Extract timestamp (part before first dash)
      if name_without_ext.include?('-')
        timestamp = name_without_ext.split('-').first
      else
        # No timestamp in current filename, use effective datetime
        effective_datetime = medium.effective_datetime || medium.created_at
        timestamp = effective_datetime.strftime("%Y%m%d_%H%M%S")
      end
      
      # Create new filename: YYYYMMDD_HHMMSS-descriptive_name.extension
      "#{timestamp}-#{descriptive_name}#{extension}"
    end
    
    # Helper to determine the correct transition name based on current state
    def determine_transition_for_medium(medium, base_transition)
      # All transitions are now consolidated - just return the base transition name
      # The consolidated events handle all source states via their 'from' arrays
      base_transition
    end
  end

  # Collection action for importing media in popup
  collection_action :import_media_popup, method: [:get, :post] do
    if request.post?
      # Handle the media import (same logic as old import_media)
      allowed_types = params[:media_types] || ['all']
      
      if params[:media_files].present?
        Rails.logger.info "=== MEDIA IMPORT DEBUG ==="
        Rails.logger.info "Allowed types: #{allowed_types}"
        Rails.logger.info "Files count: #{params[:media_files].length}"
        Rails.logger.info "User ID: #{current_user.id}"
        
        # Filter files by allowed types
        all_files = params[:media_files] || []
        filtered_files = Medium.filter_acceptable_files(all_files, allowed_types)
        
        Rails.logger.info "Total files: #{all_files.length}, Filtered files count: #{filtered_files.length}"
        
        # Generate session ID for this upload session
        session_id = session.id.to_s
        
        # Get or create upload log for this session
        upload_log = UploadLog.find_by(session_id: session_id, session_completed_at: nil)
        
        # Get total files count from frontend
        total_files_selected = params[:total_files_selected]&.to_i || all_files.length
        
        if upload_log.nil?
          # First batch - create new upload log
          batch_id = SecureRandom.uuid
          upload_log = UploadLog.create!(
            user: current_user,
            batch_id: batch_id,
            session_id: session_id,
            session_started_at: Time.current,
            user_agent: request.user_agent,
            total_files_selected: total_files_selected, # Use total files from frontend
            files_imported: 0,
            files_skipped: 0,
            files_failed: 0,
            files_data: []
          )
          Rails.logger.info "Created new UploadLog for session: #{session_id} with #{total_files_selected} total files"
          
          # Start Redis progress tracking for the session with total files count
          ProgressTrackerService.start_upload_session(session_id, current_user.id, total_files_selected)
        else
          # Subsequent batch - use existing upload log
          batch_id = upload_log.batch_id
          Rails.logger.info "Using existing UploadLog for session: #{session_id}"
        end
        
        # Start Redis progress tracking for this batch
        ProgressTrackerService.start_upload_batch(session_id, batch_id, all_files.length)
        
        # Update total files selected for this batch (only for first batch)
        if upload_log.total_files_selected < total_files_selected
          upload_log.update!(total_files_selected: total_files_selected)
        end
        
        imported_count = 0
        skipped_count = 0
        failed_count = 0
        errors = []
        skipped_files = []
        failed_files = []
        
        # Get client file paths and dates if provided
        client_file_paths = params[:client_file_paths] || []
        client_file_dates = params[:client_file_dates] || []
        
        # Process rejected files first (unsupported file types = skipped)
        rejected_files = all_files - filtered_files.map { |f| f[:file] }
        rejected_files.each_with_index do |file, index|
          # Find the client file path for this rejected file
          rejected_file_index = all_files.index(file)
          client_file_path = client_file_paths[rejected_file_index] if rejected_file_index
          
          skipped_count += 1
          skipped_files << "#{file.original_filename}: File type not supported"
          
          upload_log.add_file_data(
            filename: file.original_filename,
            file_size: file.size,
            content_type: file.content_type,
            status: 'skipped',
            skip_reason: 'File type not supported for import',
            client_file_path: client_file_path
          )
          
          # Update Redis progress as skipped (not failed)
          ProgressTrackerService.update_upload_progress(session_id, batch_id, file.original_filename, 'skipped', 'File type not supported')
        end
        
        # Process accepted files
        
        filtered_files.each_with_index do |file_info, index|
          file = file_info[:file]
          medium_type = file_info[:medium_type]
          # Find the client file path and date for this filtered file
          filtered_file_index = all_files.index(file)
          client_file_path = client_file_paths[filtered_file_index] if filtered_file_index
          client_file_date = client_file_dates[filtered_file_index] if filtered_file_index
          
          # Debug: Log received metadata
          if client_file_date.present?
            client_date = Time.at(client_file_date.to_i / 1000.0)
          Rails.logger.info "Processing #{medium_type}: #{file.original_filename} (client path: #{client_file_path})"
            Rails.logger.info "  DEBUG: Received client_file_date: #{client_file_date} -> #{client_date}"
          else
            Rails.logger.info "Processing #{medium_type}: #{file.original_filename} (client path: #{client_file_path})"
            Rails.logger.info "  DEBUG: No client_file_date received"
          end
          
          # Disable post-processing to time upload phase separately
          result = Medium.create_from_uploaded_file(file, current_user, medium_type, post_process: false, batch_id: batch_id, session_id: session_id, client_file_path: client_file_path, client_file_date: client_file_date)
          
          if result[:success]
            imported_count += 1
            Rails.logger.info "✅ Successfully imported: #{file.original_filename}"
            
            # Add successful import to upload log
            upload_log.add_file_data(
              filename: file.original_filename,
              file_size: file.size,
              content_type: file.content_type,
              status: 'imported',
              client_file_path: client_file_path,
              medium: result[:medium]
            )
            
            # Update Redis progress
            ProgressTrackerService.update_upload_progress(session_id, batch_id, file.original_filename, 'uploaded')
                else
                  error_msg = result[:error] || "Unknown error"
                  
                  # Check if this is a duplicate file (skipped, not failed)
                  if error_msg.include?('duplicate') || error_msg.include?('already exists')
                    skipped_count += 1
                    skipped_files << "#{file.original_filename}: #{error_msg}"
                    Rails.logger.info "⏭️ Skipped duplicate: #{file.original_filename} - #{error_msg}"
                    
                    # Add skipped import to upload log
                    upload_log.add_file_data(
                      filename: file.original_filename,
                      file_size: file.size,
                      content_type: file.content_type,
                      status: 'skipped',
                      skip_reason: error_msg,
                      client_file_path: client_file_path
                    )
                    
                    # Update Redis progress as skipped
                    ProgressTrackerService.update_upload_progress(session_id, batch_id, file.original_filename, 'skipped', error_msg)
                  else
                    # This is a real failure
                    failed_count += 1
                    failed_files << "#{file.original_filename}: #{error_msg}"
                    errors << "#{file.original_filename}: #{error_msg}"
                    Rails.logger.error "❌ Failed to import: #{file.original_filename} - #{error_msg}"
                    
                    # Add failed import to upload log
                    upload_log.add_file_data(
                      filename: file.original_filename,
                      file_size: file.size,
                      content_type: file.content_type,
                      status: 'failed',
                      skip_reason: error_msg,
                      client_file_path: client_file_path
                    )
                    
                    # Update Redis progress as failed
                    ProgressTrackerService.update_upload_progress(session_id, batch_id, file.original_filename, 'failed', error_msg)
                  end
                end
        end
        
        # Update the upload session statistics
        upload_log.update!(
          files_imported: upload_log.files_imported + imported_count,
          files_skipped: upload_log.files_skipped + skipped_count,
          files_failed: upload_log.files_failed + failed_count
        )
        
        # Complete batch progress tracking
        ProgressTrackerService.complete_upload_batch(session_id, batch_id)
        
        # Enqueue asynchronous post-processing for this batch
        if imported_count > 0
          Rails.logger.info "🚀 Enqueuing batch post-processing job for batch: #{batch_id}, session: #{session_id}"
          BatchPostProcessJob.perform_later(batch_id, session_id)
        end
        
        # Check if this might be the final batch by looking at frontend parameters
        is_final_batch = params[:is_final_batch] == 'true'
        
        if is_final_batch
          # Mark session as completed
          upload_log.update!(
            session_completed_at: Time.current,
            completion_status: 'complete'
          )
          Rails.logger.info "Completed UploadLog session: #{session_id}"
          
          # Complete session progress tracking
          ProgressTrackerService.complete_upload_session(session_id)
        end
        
        Rails.logger.info "=== IMPORT SUMMARY ==="
        Rails.logger.info "Successfully imported: #{imported_count}"
        Rails.logger.info "Errors: #{errors.length}"
        
        render json: { 
          status: 'success', 
          imported_count: imported_count,
          skipped_count: skipped_count,
          failed_count: failed_count,
          total_count: all_files.length,
          error_count: errors.length,
          errors: errors,
          skipped_files: skipped_files,
          failed_files: failed_files
        }
      else
        Rails.logger.error "No media files found in request"
        render json: { 
          status: 'error', 
          message: "No files provided" 
        }, status: 400
      end
    else
      # Render popup layout
      render layout: false
    end
  end

  # Member action to execute state transitions
  member_action :execute_transition, method: :get do
    transition_event = params[:transition]
    
    # Analyze the transition to determine target state
    analysis = resource.analyze_transition(transition_event)
    
    if !analysis[:allowed_transition]
      redirect_to family_medium_path(resource), alert: "This transition is not available"
      return
    end
    
    target_state = analysis[:target_state]
    
    # Store transition info in session for later execution
    session[:pending_transition] = transition_event
    session[:pending_transition_medium_id] = resource.id
    
    # Determine which form to show based on target state
    case target_state.to_s
    when 'event_root'
      # Need to select an event
      redirect_to select_event_for_transition_family_medium_path(id: resource.id)
    when 'subevent_level1'
      # Need to select event and subevent level 1
      redirect_to select_subevent_for_transition_family_medium_path(id: resource.id, level: 1)
    when 'subevent_level2'
      # Need to select event, subevent level 1, and subevent level 2
      redirect_to select_subevent_for_transition_family_medium_path(id: resource.id, level: 2)
    else
      # Direct transitions (unsorted, daily) - execute immediately
      begin
        resource.send("#{transition_event}!")
        redirect_to family_medium_path(resource), notice: "Successfully moved to #{target_state.to_s.humanize}"
      rescue => e
        redirect_to family_medium_path(resource), alert: "Failed to move: #{e.message}"
      end
    end
  end

  # Member action to show form for selecting event
  member_action :select_event_for_transition, method: :get do
    @medium = resource
    @pending_transition = session[:pending_transition]
    @existing_events = Event.order(:title)
  end

  # Member action to process event selection and execute transition
  member_action :complete_transition, method: :post do
    @medium = resource
    pending_transition = session[:pending_transition]
    
    if pending_transition.blank?
      redirect_to family_medium_path(@medium), alert: "No pending transition found"
      return
    end
    
    event_id = params[:event_id]
    # For level 2 subevents, the parameter is subevent2_id, for level 1 it's subevent_id
    subevent_id = params[:subevent2_id] || params[:subevent_id]
    
    # Set instance variables for the AASM callback to validate and use
    @medium.instance_variable_set(:@pending_event_id, event_id) if event_id.present?
    @medium.instance_variable_set(:@pending_subevent_id, subevent_id) if subevent_id.present?
    
    # Execute the state machine transition
    begin
      @medium.send("#{pending_transition}!")
      
      # Clear the session
      session[:pending_transition] = nil
      
      # Redirect to appropriate destination
      if @medium.event.present?
        redirect_to family_event_path(@medium.event), notice: "Successfully moved media."
      else
        redirect_to family_medium_path(@medium), notice: "Successfully moved media."
      end
    rescue => e
      # Clear the session
      session[:pending_transition] = nil
      
      redirect_to family_medium_path(@medium), alert: "Failed to move media: #{e.message}"
    end
  end

  # Member action to show form for selecting subevent (handles both level 1 and level 2)
  member_action :select_subevent_for_transition, method: :get do
    @medium = resource
    @pending_transition = session[:pending_transition]
    @level = params[:level].to_i
    @existing_events = Event.includes(:subevents).order(:title)
  end
  
  # Event selection page for batch "add to existing event"
  collection_action :batch_select_event, method: [:get, :post] do
    @batch_media_ids = session[:batch_media_ids] || []
    @batch_transition = session[:batch_transition]
    
    unless @batch_transition
      redirect_to collection_path, alert: "No batch transition specified"
      return
    end
    
    if request.post?
      # User selected an event, store it and proceed to validation
      event_id = params[:event_id]
      
      if event_id.blank?
        @existing_events = Event.order(:title)
        @error_message = "Please select an event"
        render 'batch_select_event'
        return
      end
      
      # Store the selected event
      session[:batch_target_event_id] = event_id
      
      # Now redirect to validation with event context
      redirect_to batch_validate_transition_family_media_path
    else
      # Show event selection form
      @media = Medium.where(id: @batch_media_ids)
      @existing_events = Event.order(:title)
      render 'batch_select_event'
    end
  end
  
  # Batch validation page from drag-and-drop in MediumSorter
  collection_action :batch_validate_transition_from_sorter, method: :post do
    media_ids = params[:media_ids].to_s.split(',').map(&:strip).reject(&:blank?).map(&:to_i)
    transition_type = params[:transition_type]
    target_event_id = params[:target_event_id]&.to_i
    target_subevent_id = params[:target_subevent_id]&.to_i
    
    unless transition_type.present? && media_ids.any?
      redirect_to collection_path, alert: "Missing required parameters"
      return
    end
    
    # Store in session (matching existing batch validation flow)
    session[:batch_media_ids] = media_ids
    session[:batch_transition] = transition_type.to_sym
    session[:batch_target_event_id] = target_event_id if target_event_id
    session[:batch_target_subevent_id] = target_subevent_id if target_subevent_id
    # Flag to indicate this came from medium_sorter page
    session[:from_medium_sorter] = true
    
    # Redirect to existing validation page
    redirect_to batch_validate_transition_family_media_path
  end
  
  # Batch validation page - shows which media can be moved
  collection_action :batch_validate_transition, method: :get do
    @batch_media_ids = session[:batch_media_ids] || []
    @batch_transition = session[:batch_transition]
    @target_event_id = session[:batch_target_event_id]
    @target_subevent_id = session[:batch_target_subevent_id]
    
    unless @batch_transition
      redirect_to collection_path, alert: "No batch transition specified"
      return
    end
    
    # If subevent_id is specified, get the event_id from the subevent
    if @target_subevent_id && !@target_event_id
      subevent = Subevent.find_by(id: @target_subevent_id)
      @target_event_id = subevent&.event_id
    end
    
    # Load target event if specified
    @target_event = Event.find_by(id: @target_event_id) if @target_event_id
    
    # Load target subevent if specified
    @target_subevent = Subevent.find_by(id: @target_subevent_id) if @target_subevent_id
    
    # Determine subevent levels
    if @target_subevent
      if @target_subevent.parent_subevent_id.present?
        @target_subevent_l1 = @target_subevent.parent_subevent
        @target_subevent_l2 = @target_subevent
      else
        @target_subevent_l1 = @target_subevent
        @target_subevent_l2 = nil
      end
    else
      @target_subevent_l1 = nil
      @target_subevent_l2 = nil
    end
    
    @media = Medium.where(id: @batch_media_ids)
    @validation_results = []
    
    @media.each do |medium|
      # Set instance variables for AASM guards to check
      medium.instance_variable_set(:@pending_event_id, @target_event_id) if @target_event_id.present?
      medium.instance_variable_set(:@pending_subevent_id, @target_subevent_id) if @target_subevent_id.present?
      
      # Determine the actual transition name based on current state
      transition_name = determine_transition_for_medium(medium, @batch_transition)
      result = medium.analyze_transition(transition_name)
      
      @validation_results << {
        medium: medium,
        transition_name: transition_name,
        can_transition: result[:allowed_transition],
        reason: result[:guard_failure_reason] || result[:error]
      }
    end
    
    @movable_count = @validation_results.count { |r| r[:can_transition] }
    @blocked_count = @validation_results.count { |r| !r[:can_transition] }
    
    render 'batch_validate_transition'
  end
  
  # Execute batch transition (for direct transitions like move_to_daily, move_to_unsorted)
  collection_action :batch_execute_transition, method: :post do
    batch_media_ids = session[:batch_media_ids] || []
    batch_transition = session[:batch_transition]
    move_blocked = params[:move_blocked] == 'true'
    
    unless batch_transition
      redirect_to collection_path, alert: "No batch transition specified"
      return
    end
    
    media = Medium.where(id: batch_media_ids)
    success_count = 0
    error_count = 0
    errors = []
    
    media.each do |medium|
      # Determine the actual transition name based on current state
      transition_name = determine_transition_for_medium(medium, batch_transition)
      result = medium.analyze_transition(transition_name)
      
      if !result[:allowed_transition] && !move_blocked
        # Skip blocked media if user chose not to move them
        next
      end
      
      begin
        if result[:allowed_transition]
          medium.send("#{transition_name}!")
          success_count += 1
        else
          errors << "#{medium.current_filename}: #{result[:guard_failure_reason] || 'Cannot transition'}"
          error_count += 1
        end
      rescue => e
        errors << "#{medium.current_filename}: #{e.message}"
        error_count += 1
      end
    end
    
    # Clear session
    session.delete(:batch_media_ids)
    session.delete(:batch_transition)
    
    # Determine redirect path - back to medium_sorter if that's where we came from
    from_sorter = session[:from_medium_sorter]
    session.delete(:from_medium_sorter)
    redirect_path = from_sorter ? family_mediumsorter_path : collection_path
    
    if error_count == 0
      redirect_to redirect_path, notice: "Successfully moved #{success_count} media files"
    elsif success_count > 0
      redirect_to redirect_path, alert: "Moved #{success_count} files, but #{error_count} failed: #{errors.first(3).join('; ')}"
    else
      redirect_to redirect_path, alert: "Failed to move files: #{errors.first(3).join('; ')}"
    end
  end
  
  # Batch select event/subevent for transition
  collection_action :batch_select_destination, method: :get do
    @batch_media_ids = session[:batch_media_ids] || []
    @batch_transition = session[:batch_transition]
    
    # Determine target state from first movable medium
    media = Medium.where(id: @batch_media_ids)
    first_movable = media.find { |m| m.analyze_transition(@batch_transition)[:allowed_transition] }
    
    if first_movable
      analysis = first_movable.analyze_transition(@batch_transition)
      @target_state = analysis[:target_state]
      @level = case @target_state
               when :subevent_level1 then 1
               when :subevent_level2 then 2
               else nil
               end
      
      @existing_events = Event.order(:title)
      render 'batch_select_destination'
    else
      redirect_to collection_path, alert: "No media can be moved with this transition"
    end
  end
  
  # Complete batch transition with event/subevent selection
  collection_action :batch_complete_transition, method: :post do
    batch_media_ids = session[:batch_media_ids] || []
    batch_transition = session[:batch_transition]
    # Get event_id from session (set by event creation or selection) or params
    event_id = session[:batch_target_event_id] || params[:event_id]
    # Get subevent_id from session (from drag-and-drop) or params
    subevent_id = session[:batch_target_subevent_id] || params[:subevent2_id] || params[:subevent_id]
    
    media = Medium.where(id: batch_media_ids)
    success_count = 0
    error_count = 0
    errors = []
    
    media.each do |medium|
      # Set instance variables for AASM guards to check
      medium.instance_variable_set(:@pending_event_id, event_id) if event_id.present?
      medium.instance_variable_set(:@pending_subevent_id, subevent_id) if subevent_id.present?
      
      # Determine the actual transition name based on current state
      transition_name = determine_transition_for_medium(medium, batch_transition)
      result = medium.analyze_transition(transition_name)
      
      # Trust the AASM guard - if it says the transition is not allowed, skip
      next unless result[:allowed_transition]
      
      begin
        medium.send("#{transition_name}!")
        success_count += 1
      rescue => e
        errors << "#{medium.current_filename}: #{e.message}"
        error_count += 1
      end
    end
    
    # Clear session
    session.delete(:batch_media_ids)
    session.delete(:batch_transition)
    session.delete(:batch_target_event_id)
    session.delete(:batch_target_subevent_id)
    
    # Determine redirect path - back to medium_sorter if that's where we came from
    from_sorter = session[:from_medium_sorter]
    session.delete(:from_medium_sorter)
    redirect_path = from_sorter ? family_mediumsorter_path : (event_id.present? ? family_event_path(event_id) : collection_path)
    
    if error_count == 0
      redirect_to redirect_path, notice: "Successfully moved #{success_count} media files"
    else
      redirect_to redirect_path, alert: "Moved #{success_count} files, but #{error_count} failed"
    end
  end

end
