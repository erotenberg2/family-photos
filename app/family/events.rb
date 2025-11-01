ActiveAdmin.register Event, namespace: :family, as: 'Events' do
  # Permitted parameters
  permit_params :title, :start_date, :end_date, :description, :created_by_id

  # Index page configuration
  index do
    selectable_column
    
    column "Title" do |event|
      link_to event.title, family_event_path(event)
    end
    
    column "Date Range" do |event|
      event.date_range_string
    end
    
    column "Duration" do |event|
      "#{event.duration_days} day#{'s' if event.duration_days != 1}"
    end

    column :folder_path
    
    column "Media Count" do |event|
      event.media_count
    end
    
    column "Subevents" do |event|
      event.subevents_count
    end
    
    column "Created By" do |event|
      event.created_by.email if event.created_by
    end
    
    column "Created" do |event|
      event.created_at.strftime("%Y-%m-%d")
    end
    
    actions
  end

  # Show page configuration
  show do
    attributes_table do
      row :id
      row :title
      row :start_date
      row :end_date
      row "Duration" do |event|
        "#{event.duration_days} day#{'s' if event.duration_days != 1}"
      end
      row :description
      row :folder_path
      row :created_by
      row :created_at
      row :updated_at
    end

    # Media in this event
    panel "Media in this Event" do
      if resource.media.any?
        table_for resource.media.includes(:mediable, :event) do
          column "Thumbnail", sortable: false do |medium|
            case medium.medium_type
            when 'photo'
              if medium.mediable&.thumbnail_path && File.exist?(medium.mediable.thumbnail_path)
                link_to family_medium_path(medium), title: "View photo details" do
                  image_tag("data:image/jpg;base64,#{Base64.encode64(File.read(medium.mediable.thumbnail_path))}", 
                            style: "max-width: 60px; max-height: 60px; object-fit: cover; border-radius: 4px; cursor: pointer;")
                end
              else
                link_to family_medium_path(medium), title: "View photo details" do
                  content_tag :div, "📷", style: "width: 60px; height: 60px; background: #f8f9fa; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px; border: 2px dashed #dee2e6; cursor: pointer;"
                end
              end
            when 'audio'
              content_tag :div, "🎵", style: "width: 60px; height: 60px; background: #f0f0f0; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px;"
            when 'video'
              content_tag :div, "🎬", style: "width: 60px; height: 60px; background: #f0f0f0; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px;"
            else
              content_tag :div, "📄", style: "width: 60px; height: 60px; background: #f0f0f0; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px;"
            end
          end
          column "Type" do |medium|
            case medium.medium_type
            when 'photo'
              "📸 Photo"
            when 'video'
              "🎬 Video"
            when 'audio'
              "🎵 Audio"
            else
              "📄 Unknown"
            end
          end
          column :original_filename
          column :current_filename
          column :effective_datetime do |medium|
            medium.effective_datetime&.strftime("%Y-%m-%d %H:%M") || "No date"
          end
          column "Storage" do |medium|
            case medium.aasm.current_state
            when :unsorted
              content_tag :div, Constants::UNSORTED_ICON, style: "font-size: 16px; text-align: center;", title: "Unsorted storage"
            when :daily
              content_tag :div, Constants::DAILY_ICON, style: "font-size: 16px; text-align: center;", title: "Daily storage"
            when :event_root
              content_tag :div, Constants::EVENT_ROOT_ICON, style: "font-size: 16px; text-align: center;", title: "Event storage"
            when :subevent_level1
              content_tag :div, Constants::SUBEVENT_LEVEL1_ICON, style: "font-size: 16px; text-align: center;", title: "Subevent level 1"
            when :subevent_level2
              content_tag :div, Constants::SUBEVENT_LEVEL2_ICON, style: "font-size: 16px; text-align: center;", title: "Subevent level 2"
            end
          end
          column "Actions" do |medium|
            link_to "View", family_medium_path(medium), class: "btn btn-sm"
          end
        end
      else
        div "No media in this event yet.", style: "padding: 20px; color: #666; text-align: center;"
      end
    end

    # Subevents
    panel "Subevents" do
      if resource.subevents.any?
        table_for resource.subevents.top_level.includes(:child_subevents) do
          column :title
          column "Hierarchy" do |subevent|
            subevent.hierarchy_path
          end
          column "Media Count" do |subevent|
            subevent.media_count
          end
          column "Child Subevents" do |subevent|
            subevent.child_subevents.count
          end
          column "Actions" do |subevent|
            link_to "View", family_subevent_path(subevent), class: "btn btn-sm"
          end
        end
      else
        div "No subevents created yet.", style: "padding: 20px; color: #666; text-align: center;"
      end
      
      div do
        link_to "Create Subevent", new_family_subevent_path(event_id: resource.id), class: "button"
      end
    end
  end

  # Form configuration
  form do |f|
    f.inputs "Event Details" do
      f.input :title
      
      # # Only show date fields for existing events
      # if f.object.persisted?
      #   f.input :start_date, as: :date_picker
      #   f.input :end_date, as: :date_picker
      # end
      
      f.input :description, as: :text
      
      # Only show created_by for existing events
      # if f.object.persisted?
      #   f.input :created_by, as: :select, collection: User.all.map { |u| [u.email, u.id] }
      # end
    end
    f.actions
  end
  
  # Controller to handle auto-filling dates for new events
  controller do
    def create
      # Set default dates to today for new events
      params[:event][:start_date] ||= Date.today
      params[:event][:end_date] ||= Date.today
      
      # Set created_by to current user
      params[:event][:created_by_id] = current_user.id if defined?(current_user) && current_user
      
      # Check if this is from a batch operation
      batch_media_ids = session[:batch_media_ids] || params[:batch_media_ids]&.split(',')
      
      create! do |success, failure|
        success.html do
          # If batch media IDs present, store the event and redirect to validation
          if batch_media_ids.present?
            # Store the newly created event ID
            session[:batch_target_event_id] = resource.id
            
            # Redirect to validation page
            redirect_to batch_validate_transition_family_media_path, notice: "Event created. Review which media can be moved."
          else
            redirect_to family_event_path(resource), notice: "Event was successfully created."
          end
        end
        
        failure.html do
          # If event creation failed and this was a batch operation, clear session and redirect
          if batch_media_ids.present?
            session.delete(:batch_media_ids)
            session.delete(:batch_transition)
            redirect_to family_media_path, alert: "Failed to create event. Batch operation cancelled."
          else
            render :new
          end
        end
      end
    end
  end

  # Filters
  filter :title
  filter :start_date
  filter :end_date
  filter :created_by
  filter :created_at

  # Scopes
  scope :all, default: true
  scope :active
  scope :past
end
