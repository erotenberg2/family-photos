ActiveAdmin.register Subevent do
  # Permitted parameters
  permit_params :title, :description, :event_id, :parent_subevent_id

  # Index page configuration
  index do
    selectable_column
    
    column "Title" do |subevent|
      link_to subevent.title, admin_subevent_path(subevent)
    end
    
    column "Event" do |subevent|
      link_to subevent.event.title, admin_event_path(subevent.event)
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
        link_to subevent.parent_subevent.title, admin_subevent_path(subevent.parent_subevent)
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
        link_to subevent.event.title, admin_event_path(subevent.event)
      end
      row "Parent Subevent" do |subevent|
        if subevent.parent_subevent
          link_to subevent.parent_subevent.title, admin_subevent_path(subevent.parent_subevent)
        else
          "Top Level"
        end
      end
      row "Hierarchy Path" do |subevent|
        subevent.hierarchy_path
      end
      row :description
      row :created_at
      row :updated_at
    end

    # Media in this subevent
    panel "Media in this Subevent" do
      if subevent.media.any?
        table_for subevent.media.includes(:mediable, :event) do
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
        div "No media in this subevent yet.", style: "padding: 20px; color: #666; text-align: center;"
      end
    end

    # Child subevents
    panel "Child Subevents" do
      if subevent.child_subevents.any?
        table_for subevent.child_subevents.includes(:child_subevents) do
          column :title
          column "Media Count" do |child|
            child.media_count
          end
          column "Grandchildren" do |child|
            child.child_subevents.count
          end
          column "Actions" do |child|
            link_to "View", admin_subevent_path(child), class: "btn btn-sm"
          end
        end
      else
        div "No child subevents.", style: "padding: 20px; color: #666; text-align: center;"
      end
    end
  end

  # Form configuration
  form do |f|
    f.inputs "Subevent Details" do
      f.input :title
      f.input :event, as: :select, collection: Event.all.map { |e| ["#{e.title} (#{e.date_range_string})", e.id] }
      f.input :parent_subevent, as: :select, 
              collection: Subevent.where.not(id: f.object.id)
                                  .select { |s| s.can_have_children? }
                                  .map { |s| [s.hierarchy_path, s.id] },
              include_blank: "Top Level"
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
