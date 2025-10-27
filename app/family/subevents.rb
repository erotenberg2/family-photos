ActiveAdmin.register Subevent, namespace: :family, as: 'Subevents' do
  # Permitted parameters
  permit_params :title, :description, :event_id, :parent_subevent_id

  # Index page configuration
  index do
    selectable_column
    
    column "Title" do |subevent|
      link_to subevent.title, family_subevent_path(subevent)
    end
    
    column "Event" do |subevent|
      link_to subevent.event.title, family_event_path(subevent.event)
    end
    
    column "Hierarchy" do |subevent|
      subevent.hierarchy_path
    end
    
    column "Depth" do |subevent|
      depth_badge = content_tag :span, "Level #{subevent.depth}", 
                      class: "badge #{subevent.max_depth_reached? ? 'badge-warning' : 'badge-info'}"
      if subevent.max_depth_reached?
        depth_badge + content_tag(:span, " (Max)", style: "color: #dc3545; font-size: 0.8em;")
      else
        depth_badge
      end
    end
    
    column "Media Count" do |subevent|
      subevent.media_count
    end
    
    column "Parent Subevent" do |subevent|
      if subevent.parent_subevent
        link_to subevent.parent_subevent.title, family_subevent_path(subevent.parent_subevent)
      else
        "Top Level"
      end
    end
    
    column "Child Subevents" do |subevent|
      subevent.child_subevents.count
    end
    
    column "Created" do |subevent|
      subevent.created_at.strftime("%Y-%m-%d")
    end
    
    actions
  end

  # Show page configuration
  show do
    attributes_table do
      row :id
      row :title
      row "Event" do |subevent|
        link_to subevent.event.title, family_event_path(subevent.event)
      end
      row "Parent Subevent" do |subevent|
        if subevent.parent_subevent
          link_to subevent.parent_subevent.title, family_subevent_path(subevent.parent_subevent)
        else
          "Top Level"
        end
      end
      row "Hierarchy Path" do |subevent|
        subevent.hierarchy_path
      end
      row "Depth" do |subevent|
        "Level #{subevent.depth}"
      end
      row :description
      row :created_at
      row :updated_at
    end

    # Media in this subevent
    panel "Media in this Subevent" do
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
          column :effective_datetime do |medium|
            medium.effective_datetime&.strftime("%Y-%m-%d %H:%M") || "No date"
          end
          column "Storage" do |medium|
            case medium.storage_class
            when 'daily'
              content_tag :div, "📅", style: "font-size: 16px; text-align: center;", title: "Daily storage"
            when 'event'
              content_tag :div, "✈️", style: "font-size: 16px; text-align: center;", title: "Event storage"
            when 'unsorted'
              content_tag :div, "📂", style: "font-size: 16px; text-align: center;", title: "Unsorted storage"
            else
              content_tag :div, "❓", style: "font-size: 16px; text-align: center;", title: "Unknown storage"
            end
          end
          column "Actions" do |medium|
            link_to "View", family_medium_path(medium), class: "btn btn-sm"
          end
        end
      else
        div "No media in this subevent yet.", style: "padding: 20px; color: #666; text-align: center;"
      end
    end

    # Child subevents
    panel "Child Subevents" do
      if resource.child_subevents.any?
        table_for resource.child_subevents.includes(:child_subevents) do
          column :title
          column "Media Count" do |child|
            child.media_count
          end
          column "Grandchildren" do |child|
            child.child_subevents.count
          end
          column "Actions" do |child|
            link_to "View", family_subevent_path(child), class: "btn btn-sm"
          end
        end
      else
        div "No child subevents.", style: "padding: 20px; color: #666; text-align: center;"
      end
      
      div do
        link_to "Create Child Subevent", new_family_subevent_path(parent_subevent_id: resource.id, event_id: resource.event_id), class: "button"
      end
    end
  end

  # Form configuration
  form do |f|
    # Extract event_id from params or existing object
    event_id = params[:event_id] || (f.object.persisted? ? f.object.event_id : nil)
    
    # If no event_id yet, check if the form has been submitted with event_id
    event_id ||= params[:subevent] && params[:subevent][:event_id]
    
    # Extract parent_subevent_id from params or existing object
    parent_subevent_id = params[:parent_subevent_id] || (f.object.persisted? ? f.object.parent_subevent_id : nil)
    
    # If no parent_subevent_id yet, check if the form has been submitted with parent_subevent_id
    parent_subevent_id ||= params[:subevent] && params[:subevent][:parent_subevent_id]
    
    f.inputs "Subevent Details" do
      f.input :title
      
      if event_id.present?
        # Use hidden field to ensure event_id persists across form submissions
        f.input :event_id, as: :hidden, input_html: { value: event_id }
        div style: "margin-bottom: 15px;" do
          "Event: #{Event.find(event_id).title}"
        end
      else
        f.input :event, as: :select, collection: Event.all.map { |e| ["#{e.title} (#{e.date_range_string})", e.id] }
      end
      
      if parent_subevent_id.present?
        # Use hidden field to ensure parent_subevent_id persists across form submissions
        f.input :parent_subevent_id, as: :hidden, input_html: { value: parent_subevent_id }
        div style: "margin-bottom: 15px;" do
          parent = Subevent.find(parent_subevent_id)
          "Parent Subevent: #{parent.hierarchy_path}"
        end
      end
      
      f.input :description, as: :text
    end
    f.actions
  end

  # Filters
  filter :title
  filter :event
  filter :parent_subevent
  filter :created_at

  # Scopes
  scope :all, default: true
  scope :top_level
end
