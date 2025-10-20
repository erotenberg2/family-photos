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
        transitions from: :unsorted, to: :event_root
      end

      event :move_to_subevent_level1 do
        transitions from: :unsorted, to: :subevent_level1
      end

      event :move_to_subevent_level2 do
        transitions from: :unsorted, to: :subevent_level2
      end

      # From daily state
      event :move_daily_to_unsorted do
        transitions from: :daily, to: :unsorted, guard: :can_move_to_unsorted?
      end

      event :move_daily_to_event do
        transitions from: :daily, to: :event_root
      end

      event :move_daily_to_subevent_level1 do
        transitions from: :daily, to: :subevent_level1
      end

      event :move_daily_to_subevent_level2 do
        transitions from: :daily, to: :subevent_level2
      end

      # From event_root state
      event :move_event_to_unsorted do
        transitions from: :event_root, to: :unsorted, guard: :can_move_to_unsorted?
      end

      event :move_event_to_daily do
        transitions from: :event_root, to: :daily, guard: :can_move_to_daily?
      end

      event :move_event_to_subevent_level1 do
        transitions from: :event_root, to: :subevent_level1
      end

      event :move_event_to_subevent_level2 do
        transitions from: :event_root, to: :subevent_level2
      end

      # From subevent_level1 state
      event :move_subevent1_to_unsorted do
        transitions from: :subevent_level1, to: :unsorted, guard: :can_move_to_unsorted?
      end

      event :move_subevent1_to_daily do
        transitions from: :subevent_level1, to: :daily, guard: :can_move_to_daily?
      end

      event :move_subevent1_to_event do
        transitions from: :subevent_level1, to: :event_root
      end

      event :move_subevent1_to_subevent2 do
        transitions from: :subevent_level1, to: :subevent_level2
      end

      # From subevent_level2 state
      event :move_subevent2_to_unsorted do
        transitions from: :subevent_level2, to: :unsorted, guard: :can_move_to_unsorted?
      end

      event :move_subevent2_to_daily do
        transitions from: :subevent_level2, to: :daily, guard: :can_move_to_daily?
      end

      event :move_subevent2_to_event do
        transitions from: :subevent_level2, to: :event_root
      end

      event :move_subevent2_to_subevent1 do
        transitions from: :subevent_level2, to: :subevent_level1
      end
    end

    # Callbacks to handle file movement and association updates
    # Only run callbacks for actual transitions, not initial state assignment
    aasm do
      after_all_transitions :handle_state_transition, if: :state_transitioned?
    end
  end

  private

  def state_transitioned?
    # Only run callbacks if this is an actual state transition, not initial assignment
    persisted? && storage_state_changed?
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
    # TODO: Implementation for moving to unsorted/files...
    Rails.logger.debug "AASM: Would move to unsorted folder"
  end

  def move_to_daily_folder
    # TODO: Implementation for moving to year/month/day/files...
    # Use created_at or a specific date attribute
    Rails.logger.debug "AASM: Would move to daily folder"
  end

  def move_to_event_root_folder
    # TODO: Implementation for moving to events/event_folder_name/files...
    Rails.logger.debug "AASM: Would move to event root folder"
  end

  def move_to_subevent_level1_folder
    # TODO: Implementation for moving to events/event_folder_name/subevent_folder_name/files...
    Rails.logger.debug "AASM: Would move to subevent level 1 folder"
  end

  def move_to_subevent_level2_folder
    # TODO: Implementation for moving to events/event_folder_name/subevent_folder_name/subevent_folder_name/files...
    Rails.logger.debug "AASM: Would move to subevent level 2 folder"
  end

  # Guard methods for AASM transitions
  def can_move_to_daily?
    # Check if a file with the same name already exists in daily storage
    #require_relative '../../lib/constants'
    
    # Calculate the target daily path
    target_date = effective_datetime&.to_date || created_at.to_date
    daily_path = File.join(Constants::DAILY_STORAGE, target_date.strftime("%Y/%m/%d"))
    target_file_path = File.join(daily_path, current_filename)
    
    # Check if file already exists at target location
    if File.exist?(target_file_path)
      Rails.logger.warn "AASM Guard: Cannot move to daily - file already exists at #{target_file_path}"
      return false
    end
    
    Rails.logger.debug "AASM Guard: Can move to daily - no file conflict at #{target_file_path}"
    true
  end

  def can_move_to_unsorted?
    # Check if a file with the same name already exists in unsorted storage
    #require_relative '../../lib/constants'
    
    # Calculate the target unsorted path
    target_file_path = File.join(Constants::UNSORTED_STORAGE, current_filename)
    
    # Check if file already exists at target location
    if File.exist?(target_file_path)
      Rails.logger.warn "AASM Guard: Cannot move to unsorted - file already exists at #{target_file_path}"
      return false
    end
    
    Rails.logger.debug "AASM Guard: Can move to unsorted - no file conflict at #{target_file_path}"
    true
  end
end