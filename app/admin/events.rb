ActiveAdmin.register Event do
  # Permitted parameters
  permit_params :title, :start_date, :end_date, :description, :created_by_id

  # Index page configuration
  index do
    selectable_column
    
    column "Title" do |event|
      link_to event.title, admin_event_path(event)
    end
    
    column "Date Range" do |event|
      event.date_range_string
    end
    
    column "Duration" do |event|
      "#{event.duration_days} day#{'s' if event.duration_days != 1}"
    end
    
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
      row :created_by
      row :created_at
      row :updated_at
    end

    # Media in this event
    panel "Media in this Event" do
      if event.media.any?
        table_for event.media.includes(:mediable, :event) do
          column "Thumbnail", sortable: false do |medium|
            case medium.medium_type
            when 'photo'
              if medium.mediable&.thumbnail_path && File.exist?(medium.mediable.thumbnail_path)
                image_tag("data:image/jpg;base64,#{Base64.encode64(File.read(medium.mediable.thumbnail_path))}", 
                          style: "max-width: 60px; max-height: 60px; object-fit: cover; border-radius: 4px;")
              else
                content_tag :div, "📷", style: "width: 60px; height: 60px; background: #f8f9fa; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px; border: 2px dashed #dee2e6;"
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
          column :effective_datetime do |medium|
            medium.effective_datetime&.strftime("%Y-%m-%d %H:%M") || "No date"
          end
          column "Storage" do |medium|
            case medium.aasm.current_state
            when :unsorted
              content_tag :div, "📂", style: "font-size: 16px; text-align: center;", title: "Unsorted storage"
            when :daily
              content_tag :div, "📅", style: "font-size: 16px; text-align: center;", title: "Daily storage"
            when :event_root
              content_tag :div, "✈️", style: "font-size: 16px; text-align: center;", title: "Event storage"
            when :subevent_level1
              content_tag :div, "✈️📂", style: "font-size: 16px; text-align: center;", title: "Subevent level 1"
            when :subevent_level2
              content_tag :div, "✈️📂📂", style: "font-size: 16px; text-align: center;", title: "Subevent level 2"
            end
          end
          column "Actions" do |medium|
            link_to "View", admin_medium_path(medium), class: "btn btn-sm"
          end
        end
      else
        div "No media in this event yet.", style: "padding: 20px; color: #666; text-align: center;"
      end
    end

    # Subevents
    panel "Subevents" do
      if event.subevents.any?
        table_for event.subevents.top_level.includes(:child_subevents) do
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
            link_to "View", admin_subevent_path(subevent), class: "btn btn-sm"
          end
        end
      else
        div "No subevents created yet.", style: "padding: 20px; color: #666; text-align: center;"
      end
    end
  end

  # Form configuration
  form do |f|
    f.inputs "Event Details" do
      f.input :title
      
      # Only show date fields for existing events
      if f.object.persisted?
        f.input :start_date, as: :date_picker
        f.input :end_date, as: :date_picker
      end
      
      f.input :description, as: :text
      
      # Only show created_by for existing events
      if f.object.persisted?
        f.input :created_by, as: :select, collection: User.all.map { |u| [u.email, u.id] }
      end
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
      
      super
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
