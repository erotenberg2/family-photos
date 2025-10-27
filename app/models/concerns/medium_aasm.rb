# app/models/concerns/medium_aasm.rb
module MediumAasm
  extend ActiveSupport::Concern

  included do
    #include AASM

    aasm column: 'storage_state' do
      # Define states
      state :unsorted, initial: true
      state :daily
      state :event_root      # Media associated with event as a whole
      state :subevent_level1 # First level subevent (e.g., "Zimbabwe")
      state :subevent_level2 # Second level subevent (e.g., "morning safari")

      # From unsorted state
      event :move_to_daily do
        transitions from: :unsorted, to: :daily, guard: :can_move_to_daily?
      end

      event :move_to_event do
        transitions from: :unsorted, to: :event_root, guard: :can_move_to_event?
      end

      event :move_to_subevent_level1 do
        transitions from: :unsorted, to: :subevent_level1, guard: :can_move_to_subevent_level1?
      end

      event :move_to_subevent_level2 do
        transitions from: :unsorted, to: :subevent_level2, guard: :can_move_to_subevent_level2?
      end

      # From daily state
      event :move_daily_to_unsorted do
        transitions from: :daily, to: :unsorted, guard: :can_move_to_unsorted?
      end

      event :move_daily_to_event do
        transitions from: :daily, to: :event_root, guard: :can_move_to_event?
      end

      event :move_daily_to_subevent_level1 do
        transitions from: :daily, to: :subevent_level1, guard: :can_move_to_subevent_level1?
      end

      event :move_daily_to_subevent_level2 do
        transitions from: :daily, to: :subevent_level2, guard: :can_move_to_subevent_level2?
      end

      # From event_root state
      event :move_event_to_unsorted do
        transitions from: :event_root, to: :unsorted, guard: :can_move_to_unsorted?
      end

      event :move_event_to_daily do
        transitions from: :event_root, to: :daily, guard: :can_move_to_daily?
      end

      event :move_event_to_subevent_level1 do
        transitions from: :event_root, to: :subevent_level1, guard: :can_move_to_subevent_level1?
      end

      event :move_event_to_subevent_level2 do
        transitions from: :event_root, to: :subevent_level2, guard: :can_move_to_subevent_level2?
      end

      # From subevent_level1 state
      event :move_subevent1_to_unsorted do
        transitions from: :subevent_level1, to: :unsorted, guard: :can_move_to_unsorted?
      end

      event :move_subevent1_to_daily do
        transitions from: :subevent_level1, to: :daily, guard: :can_move_to_daily?
      end

      event :move_subevent1_to_event do
        transitions from: :subevent_level1, to: :event_root, guard: :can_move_to_event?
      end

      event :move_subevent1_to_subevent2 do
        transitions from: :subevent_level1, to: :subevent_level2, guard: :can_move_to_subevent_level2?
      end

      # From subevent_level2 state
      event :move_subevent2_to_unsorted do
        transitions from: :subevent_level2, to: :unsorted, guard: :can_move_to_unsorted?
      end

      event :move_subevent2_to_daily do
        transitions from: :subevent_level2, to: :daily, guard: :can_move_to_daily?
      end

      event :move_subevent2_to_event do
        transitions from: :subevent_level2, to: :event_root, guard: :can_move_to_event?
      end

      event :move_subevent2_to_subevent1 do
        transitions from: :subevent_level2, to: :subevent_level1, guard: :can_move_to_subevent_level1?
      end
    end

    # Callbacks to handle file movement and association updates
    # Only run callbacks for actual transitions, not initial state assignment
    aasm do
      ensure_on_all_events :validate_transition_prerequisites
      after_all_transitions :handle_state_transition, if: :state_transitioned?
    end
  end

  private

  def state_transitioned?
    # Only run callbacks if this is an actual state transition, not initial assignment
    persisted? && storage_state_changed?
  end

  def validate_transition_prerequisites
    # Validate that required IDs are set before transitioning
    # Use @pending_event_id and @pending_subevent_id if set (passed via instance variables)
    event_id_to_use = @pending_event_id || event_id
    subevent_id_to_use = @pending_subevent_id || subevent_id
    
    case aasm.to_state
    when :event_root
      if event_id_to_use.blank?
        raise "Cannot transition to event_root state: event_id is required"
      end
      unless Event.exists?(id: event_id_to_use)
        raise "Cannot transition to event_root state: event #{event_id_to_use} does not exist"
      end
      # Set the event_id now that we've validated it
      self.event_id = event_id_to_use
    when :subevent_level1
      if subevent_id_to_use.blank?
        raise "Cannot transition to subevent_level1 state: subevent_id is required"
      end
      subevent = Subevent.find_by(id: subevent_id_to_use)
      unless subevent
        raise "Cannot transition to subevent_level1 state: subevent #{subevent_id_to_use} does not exist"
      end
      unless subevent.depth == 1
        raise "Cannot transition to subevent_level1 state: subevent #{subevent_id_to_use} is level #{subevent.depth}"
      end
      # Set the subevent_id and event_id now that we've validated them
      self.subevent_id = subevent_id_to_use
      self.event_id = subevent.event_id if event_id.blank?
    when :subevent_level2
      if subevent_id_to_use.blank?
        raise "Cannot transition to subevent_level2 state: subevent_id is required"
      end
      subevent = Subevent.find_by(id: subevent_id_to_use)
      unless subevent
        raise "Cannot transition to subevent_level2 state: subevent #{subevent_id_to_use} does not exist"
      end
      unless subevent.depth == 2
        raise "Cannot transition to subevent_level2 state: subevent #{subevent_id_to_use} is level #{subevent.depth}"
      end
      # Set the subevent_id and event_id now that we've validated them
      self.subevent_id = subevent_id_to_use
      self.event_id = subevent.event_id if event_id.blank?
    end
    # Clear instance variables after use
    @pending_event_id = nil
    @pending_subevent_id = nil
  end

  def handle_state_transition
    move_file_to_new_location
    update_associations
  end

  def move_file_to_new_location
    # Logic to physically move the file based on new state
    case aasm.to_state
    when :unsorted
      move_to_unsorted_folder
    when :daily
      move_to_daily_folder
    when :event_root
      move_to_event_root_folder
    when :subevent_level1
      move_to_subevent_level1_folder
    when :subevent_level2
      move_to_subevent_level2_folder
    end
  end

  def update_associations
    # Update event and subevent associations based on state
    case aasm.to_state
    when :unsorted, :daily
      self.event = nil
      self.subevent = nil
    when :event_root
      # event should already be set before transition
      self.subevent = nil
    when :subevent_level1, :subevent_level2
      # both event and subevent should be set before transition
    end
    
    # Update storage_class enum based on state
    update_storage_class
  end
  
  def update_storage_class
    case aasm.to_state
    when :unsorted
      self.storage_class = :unsorted
    when :daily
      self.storage_class = :daily
    when :event_root, :subevent_level1, :subevent_level2
      self.storage_class = :event
    end
  end

  def move_to_unsorted_folder
    # Implementation for moving to unsorted storage
    FileOrganizationService.move_single_to_unsorted(self)
  end

  def move_to_daily_folder
    # Implementation for moving to daily storage (year/month/day)
    FileOrganizationService.move_single_to_daily(self)
  end

  def move_to_event_root_folder
    # Implementation for moving to event root folder
    # event_id should be set before calling this transition
    if event_id.present?
      FileOrganizationService.move_single_to_event(self, event_id)
    else
      Rails.logger.error "AASM: Cannot move to event root - no event_id set"
      false
    end
  end

  def move_to_subevent_level1_folder
    # Implementation for moving to level 1 subevent folder
    # event_id and subevent_id should be set before calling this transition
    if subevent_id.present?
      FileOrganizationService.move_single_to_subevent(self, subevent_id)
    else
      Rails.logger.error "AASM: Cannot move to subevent level 1 - no subevent_id set"
      false
    end
  end

  def move_to_subevent_level2_folder
    # Implementation for moving to level 2 subevent folder
    # event_id and subevent_id should be set before calling this transition
    if subevent_id.present?
      FileOrganizationService.move_single_to_subevent(self, subevent_id)
    else
      Rails.logger.error "AASM: Cannot move to subevent level 2 - no subevent_id set"
      false
    end
  end

  # Guard methods for AASM transitions
  def can_move_to_daily?
    # Check if effective datetime is available (required for daily storage)
    if effective_datetime.blank?
      Rails.logger.warn "AASM Guard: Cannot move to daily - no effective datetime available"
      @guard_failure_reason = "no datetime available"
      return false
    end
    
    Rails.logger.debug "AASM Guard: Can move to daily - datetime available"
    true
  end

  def can_move_to_unsorted?
    # Always allow moving to unsorted - the service will handle filename conflicts
    # The FileOrganizationService will automatically append -(1), -(2) etc. if needed
    Rails.logger.debug "AASM Guard: Can move to unsorted"
    true
  end

  def can_move_to_event?
    # Check if there are any events available to move to
    if Event.count == 0
      Rails.logger.warn "AASM Guard: Cannot move to event - no events exist"
      @guard_failure_reason = "no events available"
      return false
    end
    
    Rails.logger.debug "AASM Guard: Can move to event - events exist"
    true
  end

  def can_move_to_subevent_level1?
    # Check if there are any level 1 subevents available to move to (top-level subevents have depth 1)
    # We need to check if any subevents have no parent (depth 1)
    if Subevent.top_level.count == 0
      Rails.logger.warn "AASM Guard: Cannot move to subevent level 1 - no top-level subevents exist"
      @guard_failure_reason = "no level 1 subevents available"
      return false
    end
    
    Rails.logger.debug "AASM Guard: Can move to subevent level 1 - top-level subevents exist"
    true
  end

  def can_move_to_subevent_level2?
    # Check if there are any level 2 subevents available to move to (subevents with a parent have depth 2)
    # We need to check if any subevents have a parent (depth >= 2)
    if Subevent.where.not(parent_subevent_id: nil).count == 0
      Rails.logger.warn "AASM Guard: Cannot move to subevent level 2 - no level 2 subevents exist"
      @guard_failure_reason = "no level 2 subevents available"
      return false
    end
    
    Rails.logger.debug "AASM Guard: Can move to subevent level 2 - level 2 subevents exist"
    true
  end
end