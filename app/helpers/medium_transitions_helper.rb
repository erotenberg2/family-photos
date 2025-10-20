module MediumTransitionsHelper
  def generate_transitions_menu(medium)
    available_transitions = get_available_transitions(medium)
    
    if available_transitions.empty?
      content_tag :div, "—", style: "text-align: center; color: #999;"
    else
      # Create a select dropdown with JavaScript submission to avoid form conflicts
      content_tag :select, 
                  options_for_select([["Move to...", ""]] + available_transitions.map { |t| [t[:label], t[:event]] }),
                  {
                    class: "transitions-select",
                    onchange: "submitTransition(this, #{medium.id})",
                    style: "font-size: 12px; padding: 2px 4px; border: 1px solid #ddd; border-radius: 3px; background: white; min-width: 120px;"
                  }
    end
  end

  def get_available_transitions(medium)
    # Use AASM to get available events for the current state
    available_events = medium.aasm.events(permitted: true).map(&:name)
    
    # Map AASM events to user-friendly labels
    event_labels = {
      'move_to_daily' => 'Move to Daily',
      'move_to_event' => 'Create New Event',
      'move_to_subevent_level1' => 'Add to Existing Event',
      'move_to_subevent_level2' => 'Add to Subevent',
      'move_daily_to_unsorted' => 'Move to Unsorted',
      'move_daily_to_event' => 'Create New Event',
      'move_daily_to_subevent_level1' => 'Add to Existing Event',
      'move_daily_to_subevent_level2' => 'Add to Subevent',
      'move_event_to_unsorted' => 'Move to Unsorted',
      'move_event_to_daily' => 'Move to Daily',
      'move_event_to_subevent_level1' => 'Move to Subevent L1',
      'move_event_to_subevent_level2' => 'Move to Subevent L2',
      'move_subevent1_to_unsorted' => 'Move to Unsorted',
      'move_subevent1_to_daily' => 'Move to Daily',
      'move_subevent1_to_event' => 'Move to Event Root',
      'move_subevent1_to_subevent2' => 'Move to Subevent L2',
      'move_subevent2_to_unsorted' => 'Move to Unsorted',
      'move_subevent2_to_daily' => 'Move to Daily',
      'move_subevent2_to_event' => 'Move to Event Root',
      'move_subevent2_to_subevent1' => 'Move to Subevent L1'
    }
    
    # Filter out transitions that would keep the medium in the same storage class
    filtered_events = available_events.reject do |event_name|
      case event_name.to_s
      when 'move_to_daily'
        medium.storage_class == 'daily'
      when 'move_daily_to_daily', 'move_event_to_daily', 'move_subevent1_to_daily', 'move_subevent2_to_daily'
        medium.storage_class == 'daily'
      when 'move_to_event', 'move_daily_to_event', 'move_subevent1_to_event', 'move_subevent2_to_event'
        medium.storage_class == 'event'
      when 'move_to_unsorted', 'move_daily_to_unsorted', 'move_event_to_unsorted', 'move_subevent1_to_unsorted', 'move_subevent2_to_unsorted'
        medium.storage_class == 'unsorted'
      else
        false
      end
    end
    
    # Build transitions array using filtered AASM data
    transitions = []
    filtered_events.each do |event_name|
      label = event_labels[event_name.to_s] || event_name.humanize
      transitions << {
        event: event_name,
        label: label,
        description: "Transition to #{label}"
      }
    end
    
    transitions
  end
end
