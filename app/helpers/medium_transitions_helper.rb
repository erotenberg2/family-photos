module MediumTransitionsHelper
  def generate_transitions_menu(medium)
    all_transitions = get_all_transitions_with_status(medium)
    
    if all_transitions.empty?
      content_tag :div, "—", style: "text-align: center; color: #999;"
    else
      # Create option groups for available and blocked transitions
      available_options = []
      blocked_options = []
      
      all_transitions.each do |transition|
        if transition[:available]
          available_options << [transition[:label], transition[:event]]
        elsif transition[:reason].present?
          # Only show blocked options that have a specific guard failure reason
          blocked_options << ["🚫 #{transition[:label]}", "", { disabled: true, style: "color: red; background-color: #ffe6e6;" }]
        end
        # Skip transitions that are unavailable for other reasons (not shown in menu)
      end
      
      # Combine options with separators
      select_options = []
      select_options << ["Move to...", ""]
      
      if available_options.any?
        select_options += available_options
      end
      
      if blocked_options.any?
        select_options << ["——— Blocked ———", "", { disabled: true, style: "color: #999; font-style: italic;" }] if available_options.any?
        select_options += blocked_options
      end
      
      # Create the select dropdown
      select_html = content_tag :select, 
                  options_for_select(select_options),
                  {
                    class: "transitions-select",
                    onchange: "submitTransition(this, #{medium.id})",
                    style: "font-size: 12px; padding: 2px 4px; border: 1px solid #ddd; border-radius: 3px; background: white; min-width: 140px;"
                  }
      
      # Add error messages for blocked transitions (only those with guard failure reasons)
      blocked_transitions = all_transitions.select { |t| !t[:available] && t[:reason].present? }
      error_messages = blocked_transitions.map { |t| "#{t[:label]}: #{t[:reason]}" }
      
      content_tag :div do
        content = select_html
        if error_messages.any?
          error_html = content_tag(:div, 
                                error_messages.join("; "), 
                                style: "font-size: 9px; color: red; margin-top: 2px; line-height: 1.1; max-width: 200px;")
          content += error_html
        end
        content
      end
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

  def get_all_transitions_with_status(medium)
    transitions = []
    
    # Define all possible events manually since aasm.events only returns available ones
    all_events = [
      :move_to_daily, :move_to_event, :move_to_subevent_level1, :move_to_subevent_level2,
      :move_daily_to_unsorted, :move_daily_to_event, :move_daily_to_subevent_level1, :move_daily_to_subevent_level2,
      :move_event_to_unsorted, :move_event_to_daily, :move_event_to_subevent_level1, :move_event_to_subevent_level2,
      :move_subevent1_to_unsorted, :move_subevent1_to_daily, :move_subevent1_to_event, :move_subevent1_to_subevent2,
      :move_subevent2_to_unsorted, :move_subevent2_to_daily, :move_subevent2_to_event, :move_subevent2_to_subevent1
    ]
    
    Rails.logger.debug "MediumTransitionsHelper: Checking #{all_events.length} events for medium #{medium.id}: #{all_events.inspect}"
    
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
    
    # Use analyze_transition method to check each event
    all_events.each do |event_name|
      analysis = medium.analyze_transition(event_name)
      
      Rails.logger.debug "MediumTransitionsHelper: Event #{event_name}, Analysis: #{analysis}"
      
      # Check if transition is allowed (ignoring guards)
      allowed = analysis[:allowed_transition] == true
      
      # Check guard results if transition is allowed
      guard_failure_reason = nil
      if allowed && analysis[:guard_results]
        failed_guards = analysis[:guard_results].select { |guard_name, result| result == false }
        if failed_guards.any?
          guard_failure_reason = failed_guards.map { |guard_name, _| guard_name.to_s.humanize.downcase }.join(", ")
        end
      end
      
      # Only include transitions that are allowed (whether guards pass or fail)
      # Skip inherently disallowed transitions
      if allowed
        transitions << {
          event: event_name,
          available: guard_failure_reason.nil?,
          reason: guard_failure_reason,
          label: event_labels[event_name.to_s] || event_name.to_s.humanize
        }
      end
    end
    
    Rails.logger.debug "MediumTransitionsHelper: Final transitions for medium #{medium.id}: #{transitions.inspect}"
    
    transitions
  end

end
