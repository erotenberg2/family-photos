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
        before do
          perform_file_move(:daily)
        end
        transitions from: :unsorted, to: :daily, guard: :can_move_to_daily?
      end

      event :move_to_event do
        before do
          validate_to_events_transitions
          perform_file_move(:event_root)
        end
        transitions from: :unsorted, to: :event_root, guard: :can_move_to_event?
      end

      event :move_to_subevent_level1 do
        before do
          validate_to_events_transitions
          perform_file_move(:subevent_level1)
        end
        transitions from: :unsorted, to: :subevent_level1, guard: :can_move_to_subevent_level1?
      end

      event :move_to_subevent_level2 do
        before do
          validate_to_events_transitions
          perform_file_move(:subevent_level2)
        end
        transitions from: :unsorted, to: :subevent_level2, guard: :can_move_to_subevent_level2?
      end

      # From daily state
      event :move_daily_to_unsorted do
        before do
          perform_file_move(:unsorted)
        end
        transitions from: :daily, to: :unsorted, guard: :can_move_to_unsorted?
      end

      event :move_daily_to_event do
        before do
          validate_to_events_transitions
          perform_file_move(:event_root)
        end
        transitions from: :daily, to: :event_root, guard: :can_move_to_event?
      end

      event :move_daily_to_subevent_level1 do
        before do
          validate_to_events_transitions
          perform_file_move(:subevent_level1)
        end
        transitions from: :daily, to: :subevent_level1, guard: :can_move_to_subevent_level1?
      end

      event :move_daily_to_subevent_level2 do
        before do
          validate_to_events_transitions
          perform_file_move(:subevent_level2)
        end
        transitions from: :daily, to: :subevent_level2, guard: :can_move_to_subevent_level2?
      end

      # From event_root state
      event :move_event_to_unsorted do
        before do
          perform_file_move(:unsorted)
        end
        transitions from: :event_root, to: :unsorted, guard: :can_move_to_unsorted?
      end

      event :move_event_to_daily do
        before do
          perform_file_move(:daily)
        end
        transitions from: :event_root, to: :daily, guard: :can_move_to_daily?
      end

      event :move_event_to_subevent_level1 do
        before do
          validate_to_events_transitions
          perform_file_move(:subevent_level1)
        end
        transitions from: :event_root, to: :subevent_level1, guard: :can_move_to_subevent_level1?
      end

      event :move_event_to_subevent_level2 do
        before do
          validate_to_events_transitions
          perform_file_move(:subevent_level2)
        end
        transitions from: :event_root, to: :subevent_level2, guard: :can_move_to_subevent_level2?
      end

      # From subevent_level1 state
      event :move_subevent1_to_unsorted do
        before do
          perform_file_move(:unsorted)
        end
        transitions from: :subevent_level1, to: :unsorted, guard: :can_move_to_unsorted?
      end

      event :move_subevent1_to_daily do
        before do
          perform_file_move(:daily)
        end
        transitions from: :subevent_level1, to: :daily, guard: :can_move_to_daily?
      end

      event :move_subevent1_to_event do
        before do
          perform_file_move(:event_root)
        end
        transitions from: :subevent_level1, to: :event_root, guard: :can_move_to_event?
      end

      event :move_subevent1_to_subevent2 do
        before do
          validate_to_events_transitions
          perform_file_move(:subevent_level2)
        end
        transitions from: :subevent_level1, to: :subevent_level2, guard: :can_move_to_subevent_level2?
      end

      # From subevent_level2 state
      event :move_subevent2_to_unsorted do
        before do
          perform_file_move(:unsorted)
        end
        transitions from: :subevent_level2, to: :unsorted, guard: :can_move_to_unsorted?
      end

      event :move_subevent2_to_daily do
        before do
          perform_file_move(:daily)
        end
        transitions from: :subevent_level2, to: :daily, guard: :can_move_to_daily?
      end

      event :move_subevent2_to_event do
        before do
          perform_file_move(:event_root)
        end
        transitions from: :subevent_level2, to: :event_root, guard: :can_move_to_event?
      end

      event :move_subevent2_to_subevent1 do
        before do
          perform_file_move(:subevent_level1)
        end
        transitions from: :subevent_level2, to: :subevent_level1, guard: :can_move_to_subevent_level1?
      end
    end

    # Callbacks to handle post-transition verification and updates
    # Only run callbacks for actual transitions, not initial state assignment
    aasm do
      # AFTER state change: Verify file moved successfully
      after_all_transitions :verify_file_location, if: :state_transitioned?
      
      # AFTER state change: Update associations
      after_all_transitions :update_associations, if: :state_transitioned?
      
      # AFTER state change: Refresh event date range and folder naming
      after_all_transitions :refresh_event_dates_and_folder, if: :state_transitioned?
    end
  end

  private

  def state_transitioned?
    # Only run callbacks if this is an actual state transition, not initial assignment
    persisted? && storage_state_changed?
  end

  # Perform the actual file move based on target state
  # Returns true if successful, false otherwise
  # NOTE: This only moves the file on disk, does NOT update database
  # Database will be updated after AASM transition completes
  def perform_file_move(target_state)
    require_relative '../../../lib/constants'
    
    begin
      Rails.logger.info "---- now moving: medium #{id} (#{current_filename})"
      Rails.logger.info "from_state=#{aasm.current_state} target_state=#{target_state} storage_class=#{storage_class}"
      Rails.logger.info "source_path=#{full_file_path} exists=#{full_file_path.present? && File.exist?(full_file_path)}"
      # Capture previous event context before any association changes
      @previous_event_id = event_id if instance_variable_get(:@previous_event_id).nil?
      
      case target_state
      when :unsorted
        move_file_to_unsorted
      when :daily
        move_file_to_daily
      when :event_root
        if event_id.present?
          Rails.logger.info "event_id present=#{event_id} event_folder=#{event&.folder_name}"
          move_file_to_event
        else
          Rails.logger.error "Cannot move to event - no event_id set"
          false
        end
      when :subevent_level1, :subevent_level2
        if subevent_id.present?
          Rails.logger.info "subevent_id present=#{subevent_id} subevent_depth=#{subevent&.depth}"
          move_file_to_subevent
        else
          Rails.logger.error "Cannot move to subevent - no subevent_id set"
          false
        end
      else
        Rails.logger.warn "Unknown target state: #{target_state}"
        false
      end
    rescue => e
      Rails.logger.error "File move failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end
  
  # Move file to unsorted (only moves file, doesn't update DB)
  def move_file_to_unsorted
    # Ensure we have fresh DB values in case the event folder was renamed mid-batch
    reload
    old_path = file_path  # Save old path for cleanup
    source_path = full_file_path
    dest_dir = Constants::UNSORTED_STORAGE
    
    FileUtils.mkdir_p(dest_dir) unless Dir.exist?(dest_dir)
    
    unless source_path && File.exist?(source_path)
      Rails.logger.warn "⚠️ move_file_to_unsorted: source missing at expected path, attempting fallback search. expected=#{source_path}"
      # Try to find by filename anywhere under storage roots
      candidates = Medium.search_for_file(current_filename)
      if candidates.any?
        source_path = candidates.first
        old_path = File.dirname(source_path)
        Rails.logger.info "✅ Fallback found source at: #{source_path}"
      else
        Rails.logger.error "❌ move_file_to_unsorted: source file not found anywhere for #{current_filename}"
        return false
      end
    end
    
    # Resolve destination filename conflicts (OS and DB) without touching the database yet
    dest_filename = current_filename
    dest_path = File.join(dest_dir, dest_filename)
    db_conflict = Medium.where.not(id: id).where("LOWER(current_filename) = ?", dest_filename.downcase).exists?
    Rails.logger.info "unsorted: initial_dest=#{dest_path} exists_os=#{File.exist?(dest_path)} db_conflict=#{db_conflict}"
    
    if File.exist?(dest_path) || Medium.where.not(id: id).where("LOWER(current_filename) = ?", dest_filename.downcase).exists?
      extension = File.extname(dest_filename)
      base_name = File.basename(dest_filename, extension)
      
      # Detect existing -(N) suffix and increment
      suffix_match = base_name.match(/-\((\d+)\)$/)
      counter = suffix_match ? suffix_match[1].to_i + 1 : 1
      base_core = suffix_match ? base_name.sub(/-\(\d+\)$/, '') : base_name
      
      loop do
        candidate = "#{base_core}-(#{counter})#{extension}"
        candidate_path = File.join(dest_dir, candidate)
        db_exists = Medium.where.not(id: id).where("LOWER(current_filename) = ?", candidate.downcase).exists?
        Rails.logger.info "unsorted: try_candidate=#{candidate_path} exists_os=#{File.exist?(candidate_path)} db_conflict=#{db_exists}"
        if !File.exist?(candidate_path) && !db_exists
          dest_filename = candidate
          dest_path = candidate_path
          break
        end
        counter += 1
        break if counter > 1000
      end
    end
    
    # Perform move
    begin
      Rails.logger.info "unsorted: moving #{source_path} -> #{dest_path}"
      if source_path == dest_path
        # Already correct location
        self.file_path = dest_dir
        Rails.logger.info "✅ File already at unsorted: #{dest_path}"
        return true
      end
      FileUtils.mv(source_path, dest_path)
      # Update in-memory attributes (persisted after transition)
      self.file_path = dest_dir
      self.current_filename = File.basename(dest_path)
      Rails.logger.info "✅ Moved file to unsorted: #{dest_path}"
      # Clean up empty directories in source location
      cleanup_empty_directories(old_path)
      true
    rescue => e
      Rails.logger.error "❌ Failed to move to unsorted: #{e.message}"
      false
    end
  end
  
  # Move file to daily storage (only moves file, doesn't update DB)
  def move_file_to_daily
    unless has_valid_datetime?
      Rails.logger.error "Cannot move to daily - no valid datetime"
      return false
    end
    
    old_path = file_path  # Save old path for cleanup
    date = effective_datetime
    year = date.year.to_s
    month = date.month.to_s.rjust(2, '0')
    day = date.day.to_s.rjust(2, '0')
    
    daily_dir = File.join(Constants::DAILY_STORAGE, year, month, day)
    new_path = File.join(daily_dir, current_filename)
    
    FileUtils.mkdir_p(daily_dir) unless Dir.exist?(daily_dir)
    
    Rails.logger.info "daily: dest_dir=#{daily_dir} dest_path=#{new_path}"
    if File.exist?(full_file_path) && full_file_path != new_path
      Rails.logger.info "daily: moving #{full_file_path} -> #{new_path}"
      FileUtils.mv(full_file_path, new_path)
      # Update in-memory attributes (will be saved by AASM)
      self.file_path = daily_dir
      Rails.logger.info "✅ Moved file to: #{new_path}"
      
      # Clean up empty directories in source location
      cleanup_empty_directories(old_path)
      true
    else
      unless File.exist?(full_file_path)
        Rails.logger.error "❌ move_file_to_daily: source file missing: #{full_file_path}"
        return false
      end
      Rails.logger.info "daily: already at destination #{new_path}"
      # Already at destination
      self.file_path = daily_dir
      true
    end
  end
  
  # Move file to event root (only moves file, doesn't update DB)
  def move_file_to_event
    old_path = file_path  # Save old path for cleanup
    event_dir = File.join(Constants::EVENTS_STORAGE, event.folder_name)
    new_path = File.join(event_dir, current_filename)
    
    FileUtils.mkdir_p(event_dir) unless Dir.exist?(event_dir)
    
    Rails.logger.info "event: dest_dir=#{event_dir} dest_path=#{new_path}"
    if File.exist?(full_file_path) && full_file_path != new_path
      Rails.logger.info "event: moving #{full_file_path} -> #{new_path}"
      FileUtils.mv(full_file_path, new_path)
      # Update in-memory attributes (will be saved by AASM)
      self.file_path = event_dir
      Rails.logger.info "✅ Moved file to: #{new_path}"
      
      # Clean up empty directories in source location
      cleanup_empty_directories(old_path)
      true
    else
      unless File.exist?(full_file_path)
        Rails.logger.error "❌ move_file_to_event: source file missing: #{full_file_path}"
        return false
      end
      Rails.logger.info "event: already at destination #{new_path}"
      # Already at destination
      self.file_path = event_dir
      true
    end
  end
  
  # Move file to subevent (only moves file, doesn't update DB)
  def move_file_to_subevent
    old_path = file_path  # Save old path for cleanup
    event_dir = File.join(Constants::EVENTS_STORAGE, event.folder_name)
    
    if subevent.parent_subevent_id.present?
      # Level 2 subevent
      parent = subevent.parent_subevent
      subevent_dir = File.join(event_dir, parent.footer_name, subevent.footer_name)
    else
      # Level 1 subevent
      subevent_dir = File.join(event_dir, subevent.footer_name)
    end
    
    new_path = File.join(subevent_dir, current_filename)
    
    FileUtils.mkdir_p(subevent_dir) unless Dir.exist?(subevent_dir)
    
    Rails.logger.info "subevent: dest_dir=#{subevent_dir} dest_path=#{new_path}"
    if File.exist?(full_file_path) && full_file_path != new_path
      Rails.logger.info "subevent: moving #{full_file_path} -> #{new_path}"
      FileUtils.mv(full_file_path, new_path)
      # Update in-memory attributes (will be saved by AASM)
      self.file_path = subevent_dir
      Rails.logger.info "✅ Moved file to: #{new_path}"
      
      # Clean up empty directories in source location
      cleanup_empty_directories(old_path)
      true
    else
      unless File.exist?(full_file_path)
        Rails.logger.error "❌ move_file_to_subevent: source file missing: #{full_file_path}"
        return false
      end
      Rails.logger.info "subevent: already at destination #{new_path}"
      # Already at destination
      self.file_path = subevent_dir
      true
    end
  end
  
  # Clean up empty directories after moving a file
  # Walks up the directory tree removing empty directories until hitting a storage root
  def cleanup_empty_directories(old_file_path)
    return unless old_file_path
    
    # Walk up the directory tree and remove empty directories
    dir_path = old_file_path
    
    while dir_path && dir_path != Constants::UNSORTED_STORAGE && 
          dir_path != Constants::DAILY_STORAGE && dir_path != Constants::EVENTS_STORAGE
      if Dir.exist?(dir_path) && Dir.empty?(dir_path)
        begin
          Dir.rmdir(dir_path)
          Rails.logger.debug "Removed empty directory: #{dir_path}"
          dir_path = File.dirname(dir_path)  # Move up one level
        rescue => e
          Rails.logger.debug "Could not remove directory #{dir_path}: #{e.message}"
          break
        end
      else
        break  # Directory not empty or doesn't exist, stop here
      end
    end
  end
  
  def validate_to_events_transitions
    Rails.logger.info "=== VALIDATE TO EVENTS TRANSITIONS ==="
    Rails.logger.info "@pending_event_id: #{@pending_event_id.inspect}"
    Rails.logger.info "@pending_subevent_id: #{@pending_subevent_id.inspect}"
    Rails.logger.info "current event_id: #{event_id.inspect}"
    Rails.logger.info "current subevent_id: #{subevent_id.inspect}"
    
    # Validate that required IDs are set before transitioning
    # Use @pending_event_id and @pending_subevent_id if set (passed via instance variables)
    event_id_to_use = @pending_event_id || event_id
    subevent_id_to_use = @pending_subevent_id || subevent_id
    
    Rails.logger.info "aasm.to_state: #{aasm.to_state.inspect} (class: #{aasm.to_state.class})"
    
    # In a before callback, aasm.to_state is nil, so we determine the target state
    # based on which parameters are provided
    if event_id_to_use.present? && subevent_id_to_use.blank?
      # Moving to event_root
      Rails.logger.info "Moving to event_root with event_id: #{event_id_to_use}"
      unless Event.exists?(id: event_id_to_use)
        raise "Cannot transition to event_root state: event #{event_id_to_use} does not exist"
      end
      # Set the event_id now that we've validated it
      self.event_id = event_id_to_use
      Rails.logger.info "After setting event_id, self.event_id: #{self.event_id.inspect}"
    elsif subevent_id_to_use.present?
      subevent = Subevent.find_by(id: subevent_id_to_use)
      unless subevent
        raise "Cannot transition to subevent state: subevent #{subevent_id_to_use} does not exist"
      end
      # Set the subevent_id and event_id now that we've validated them
      self.subevent_id = subevent_id_to_use
      self.event_id = subevent.event_id if event_id.blank?
      Rails.logger.info "Set subevent_id: #{subevent_id_to_use} (depth: #{subevent.depth}), event_id: #{subevent.event_id}"
    else
      Rails.logger.info "No case matched - event_id_to_use: #{event_id_to_use.inspect}, subevent_id_to_use: #{subevent_id_to_use.inspect}"
    end
    # Clear instance variables after use
    Rails.logger.info "At end of validate_to_events_transitions, event_id: #{event_id.inspect}"
    Rails.logger.info "At end of validate_to_events_transitions, subevent_id: #{subevent_id.inspect}"
    @pending_event_id = nil
    @pending_subevent_id = nil
    Rails.logger.info "=== END VALIDATE TO EVENTS TRANSITIONS ==="
  end

  # Verify that file is in the correct location after state change
  def verify_file_location
    Rails.logger.info "=== VERIFY FILE LOCATION ==="
    Rails.logger.info "State: #{aasm.to_state}, event_id: #{event_id.inspect}, subevent_id: #{subevent_id.inspect}"
    
    expected_path = calculate_expected_file_path(aasm.to_state)
    actual_path = full_file_path
    
    if expected_path && actual_path == expected_path && File.exist?(actual_path)
      Rails.logger.info "✅ File verified at correct location: #{actual_path}"
      true
    else
      Rails.logger.error "❌ File verification failed!"
      Rails.logger.error "  Expected: #{expected_path}"
      Rails.logger.error "  Actual: #{actual_path}"
      Rails.logger.error "  File exists: #{File.exist?(actual_path) if actual_path}"
      # File is not where it should be - this is a critical error
      # The state change already happened, so we log the error
      false
    end
    
    Rails.logger.info "=== END VERIFY FILE LOCATION ==="
  end
  
  # Calculate where the file should be based on the target state
  def calculate_expected_file_path(target_state)
    require_relative '../../../lib/constants'
    
    case target_state
    when :unsorted
      File.join(Constants::UNSORTED_STORAGE, current_filename)
    when :daily
      return nil unless has_valid_datetime?
      date = effective_datetime
      year = date.year.to_s
      month = date.month.to_s.rjust(2, '0')
      day = date.day.to_s.rjust(2, '0')
      File.join(Constants::DAILY_STORAGE, year, month, day, current_filename)
    when :event_root
      return nil unless event_id.present? && event
      File.join(Constants::EVENTS_STORAGE, event.folder_name, current_filename)
    when :subevent_level1, :subevent_level2
      return nil unless subevent_id.present? && subevent && event
      event_dir = File.join(Constants::EVENTS_STORAGE, event.folder_name)
      
      if subevent.parent_subevent_id.present?
        # Level 2 subevent
        parent = subevent.parent_subevent
        File.join(event_dir, parent.footer_name, subevent.footer_name, current_filename)
      else
        # Level 1 subevent
        File.join(event_dir, subevent.footer_name, current_filename)
      end
    else
      nil
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

  # After a transition, recompute event date ranges and ensure folder names match
  def refresh_event_dates_and_folder
    begin
      # Destination event (if any)
      if event_id.present? && event
        event.recalculate_date_range_from_all_media!
      end
      
      # Origin event (if moved away)
      if @previous_event_id.present? && @previous_event_id != event_id
        if (prev = Event.find_by(id: @previous_event_id))
          prev.recalculate_date_range_from_all_media!
        end
      end
    rescue => e
      Rails.logger.error "Failed to refresh event dates/folder: #{e.message}"
    ensure
      @previous_event_id = nil
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