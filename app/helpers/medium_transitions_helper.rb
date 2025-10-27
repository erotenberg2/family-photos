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
          available_options << [transition[:label], transition[:event].to_s]
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

  def get_all_transitions_with_status(medium)
    transitions = []
    
    # Use AASM's events to get all possible transitions dynamically
    # We need to check all events from all states, so we query the AASM definition
    all_events = medium.class.aasm.events.map(&:name)
    
    # Use analyze_transition method to check each event
    all_events.each do |event_name|
      analysis = medium.analyze_transition(event_name)
      
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
          label: event_name.to_s.humanize,  # Just humanize the event name
          target_state: analysis[:target_state]  # Include target state
        }
      end
    end
    
    transitions
  end

end
