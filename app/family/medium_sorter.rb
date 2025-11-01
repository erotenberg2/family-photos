# frozen_string_literal: true
ActiveAdmin.register_page "MediumSorter", namespace: :family do
  menu priority: 10, label: "Medium Sorter"

  content title: "Medium Sorter" do
    # Include the medium sorter JavaScript
    content_for :head do
      javascript_include_tag 'active_admin', 'data-turbo-track': 'reload'
    end
    
    div id: "medium-sorter-container" do
      # Container for three listboxes will be rendered by JavaScript
      div id: "medium-sorter-content" do
        para "Loading media..."
      end
    end
  end

  page_action :data, method: :get do
    # Build data for unsorted media
    unsorted_media = Medium.where(storage_state: :unsorted).includes(:user, :uploaded_by)
    unsorted_data = build_date_hierarchy(unsorted_media)

    # Build data for daily media
    daily_media = Medium.where(storage_state: :daily).includes(:user, :uploaded_by)
    daily_data = build_date_hierarchy(daily_media)

    # Build data for event hierarchy media
    event_media = Medium.where(storage_state: [:event_root, :subevent_level1, :subevent_level2])
                        .includes(:event, :subevent, :user, :uploaded_by)
    event_data = build_event_hierarchy(event_media)

    render json: {
      unsorted: unsorted_data,
      daily: daily_data,
      events: event_data
    }
  end

  controller do
    private

    def build_date_hierarchy(media)
      # Group by year/month/day
      hierarchy = {}
      
      media.each do |medium|
        dt = medium.effective_datetime || medium.created_at
        year = dt.year.to_s
        month = dt.month.to_s.rjust(2, '0')
        day = dt.day.to_s.rjust(2, '0')
        
        hierarchy[year] ||= {}
        hierarchy[year][month] ||= {}
        hierarchy[year][month][day] ||= []
        
        hierarchy[year][month][day] << {
          id: medium.id,
          filename: medium.current_filename,
          original_filename: medium.original_filename,
          medium_type: medium.medium_type,
          icon: Constants.icon_for_medium_type(medium.medium_type),
          effective_datetime: medium.effective_datetime&.iso8601,
          created_at: medium.created_at.iso8601,
          file_size: medium.file_size,
          file_size_human: medium.file_size_human
        }
      end
      
      # Convert to nested array structure with proper numerical sorting (chronological order: oldest first)
      hierarchy.sort_by { |year, _| year.to_i }.map do |year, months|
        year_node = {
          type: 'year',
          label: year,
          key: year,
          children: months.sort_by { |month, _| month.to_i }.map do |month, days|
            month_node = {
              type: 'month',
              label: month,
              key: "#{year}/#{month}",
              children: days.sort_by { |day, _| day.to_i }.map do |day, items|
                day_node = {
                  type: 'day',
                  label: day,
                  key: "#{year}/#{month}/#{day}",
                  children: items.map do |item|
                    {
                      type: 'medium',
                      label: item[:filename] || item[:original_filename],
                      key: "medium_#{item[:id]}",
                      data: item
                    }
                  end
                }
                day_node if day_node[:children].any?
              end.compact
            }
            month_node if month_node[:children].any?
          end.compact
        }
        year_node if year_node[:children].any?
      end.compact
    end

    def build_event_hierarchy(media)
      # Group by event -> subevent -> media
      hierarchy = {}
      
      # First, organize media by event
      media.each do |medium|
        next unless medium.event
        
        event_id = medium.event.id
        event_title = medium.event.title
        
        hierarchy[event_id] ||= {
          id: event_id,
          title: event_title,
          root_media: [],
          subevents: {}
        }
        
        case medium.storage_state.to_s
        when 'event_root'
          hierarchy[event_id][:root_media] << {
          id: medium.id,
          filename: medium.current_filename,
          original_filename: medium.original_filename,
          medium_type: medium.medium_type,
          icon: Constants.icon_for_medium_type(medium.medium_type),
          effective_datetime: medium.effective_datetime&.iso8601,
          created_at: medium.created_at.iso8601,
          file_size: medium.file_size,
          file_size_human: medium.file_size_human,
          storage_state: medium.storage_state
        }
        when 'subevent_level1', 'subevent_level2'
          next unless medium.subevent
          
          subevent_id = medium.subevent.id
          subevent_title = medium.subevent.title
          parent_subevent_id = medium.subevent.parent_subevent_id
          
          # Create subevent entry if it doesn't exist
          hierarchy[event_id][:subevents][subevent_id] ||= {
            id: subevent_id,
            title: subevent_title,
            parent_id: parent_subevent_id,
            depth: medium.subevent.depth,
            media: []
          }
          
          hierarchy[event_id][:subevents][subevent_id][:media] << {
            id: medium.id,
            filename: medium.current_filename,
            original_filename: medium.original_filename,
            medium_type: medium.medium_type,
            icon: Constants.icon_for_medium_type(medium.medium_type),
            effective_datetime: medium.effective_datetime&.iso8601,
            created_at: medium.created_at.iso8601,
            file_size: medium.file_size,
            file_size_human: medium.file_size_human,
            storage_state: medium.storage_state
          }
        end
      end
      
      # Build nested structure: event -> subevent level1 -> subevent level2 -> media
      # Sort events alphabetically by title
      hierarchy.values.sort_by { |e| e[:title] || '' }.map do |event_data|
        # Build subevent tree
        subevent_tree = build_subevent_tree(event_data[:subevents].values)
        
        # Build children array: root media + subevent tree
        children = []
        
        # Add root media if any
        if event_data[:root_media].any?
          children.concat(event_data[:root_media].map do |item|
            {
              type: 'medium',
              label: item[:filename] || item[:original_filename],
              key: "medium_#{item[:id]}",
              data: item
            }
          end)
        end
        
        # Add subevent tree
        children.concat(subevent_tree)
        
        {
          type: 'event',
          label: event_data[:title],
          key: "event_#{event_data[:id]}",
          children: children
        }
      end
    end

    def build_subevent_tree(subevents)
      # Build tree structure from flat subevents
      # Level 1 subevents have no parent, Level 2 have parent
      # Sort alphabetically by title
      level1 = subevents.select { |s| s[:parent_id].nil? }.sort_by { |s| s[:title] || '' }
      
      level1.map do |subevent|
        children = []
        
        # Add media for this subevent
        if subevent[:media].any?
          children.concat(subevent[:media].map do |item|
            {
              type: 'medium',
              label: item[:filename] || item[:original_filename],
              key: "medium_#{item[:id]}",
              data: item
            }
          end)
        end
        
        # Find child subevents (level 2), sorted alphabetically
        child_subevents = subevents.select { |s| s[:parent_id] == subevent[:id] }.sort_by { |s| s[:title] || '' }
        if child_subevents.any?
          children.concat(child_subevents.map do |child|
            {
              type: 'subevent_l2',
              label: child[:title],
              key: "subevent_#{child[:id]}",
              children: child[:media].map do |item|
                {
                  type: 'medium',
                  label: item[:filename] || item[:original_filename],
                  key: "medium_#{item[:id]}",
                  data: item
                }
              end
            }
          end)
        end
        
        {
          type: 'subevent_l1',
          label: subevent[:title],
          key: "subevent_#{subevent[:id]}",
          children: children
        }
      end
    end
  end
end

