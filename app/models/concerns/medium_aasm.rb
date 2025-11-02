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

      # From unsorted or daily state to event_root
      event :move_to_event do
        before do
          capture_source_path_before_move
          validate_to_events_transitions
          unless perform_file_move(:event_root)
            raise "Failed to move file to event_root - file move operation failed"
          end
        end
        transitions from: [:unsorted, :daily], to: :event_root, guard: :can_move_to_event?
      end

      # From unsorted, daily, event_root, or subevent_level2 state to subevent_level1
      event :move_to_subevent_level1 do
        before do
          capture_source_path_before_move
          validate_to_events_transitions
          unless perform_file_move(:subevent_level1)
            raise "Failed to move file to subevent_level1 - file move operation failed"
          end
        end
        transitions from: [:unsorted, :daily, :event_root, :subevent_level1, :subevent_level2], to: :subevent_level1, 
          guard: :can_move_to_subevent_level1?
      end

      # From unsorted, daily, event_root, or subevent_level1 state to subevent_level2
      event :move_to_subevent_level2 do
        before do
          capture_source_path_before_move
          validate_to_events_transitions
          unless perform_file_move(:subevent_level2)
            raise "Failed to move file to subevent_level2 - file move operation failed"
          end
        end
        transitions from: [:unsorted, :daily, :event_root, :subevent_level1, :subevent_level2], to: :subevent_level2, guard: :can_move_to_subevent_level2?
      end

      # From daily or event_root state to unsorted
      event :move_to_unsorted do
        before do
          perform_file_move(:unsorted)
        end
        transitions from: [:daily, :event_root], to: :unsorted, guard: :can_move_to_unsorted?
      end

      # From event_root state
      event :move_event_to_daily do
        before do
          perform_file_move(:daily)
        end
        transitions from: :event_root, to: :daily, guard: :can_move_to_daily?
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

  # Capture source file path before associations are updated
  def capture_source_path_before_move
    @source_path_before_move = full_file_path
    Rails.logger.info "📁 [capture_source_path_before_move] Medium #{id}: Captured source path: #{@source_path_before_move}"
    Rails.logger.info "   Current state: #{aasm.current_state}"
    Rails.logger.info "   event_id: #{event_id}, subevent_id: #{subevent_id}"
  end

  # Perform the actual file move based on target state
  # Returns true if successful, false otherwise
  # NOTE: This only moves the file on disk, does NOT update database
  # Database will be updated after AASM transition completes
  def perform_file_move(target_state)
    require_relative '../../../lib/constants'
    
    Rails.logger.info "📁 [perform_file_move] Medium #{id || 'new'}: Starting file move"
    Rails.logger.info "   Current state: #{aasm.current_state}"
    Rails.logger.info "   Target state: #{target_state}"
    Rails.logger.info "   Current filename: #{current_filename}"
    Rails.logger.info "   event_id: #{event_id}, subevent_id: #{subevent_id}"
    Rails.logger.info "   @pending_event_id: #{@pending_event_id}, @pending_subevent_id: #{@pending_subevent_id}"
    
    begin
      # Use captured source path if available (captured before associations were updated)
      # Otherwise fall back to current full_file_path (for backward compatibility)
      source_path = @source_path_before_move || full_file_path
      source_exists = source_path.present? && File.exist?(source_path)
      Rails.logger.info "   Source path (captured): #{@source_path_before_move}" if @source_path_before_move
      Rails.logger.info "   Source path (current): #{source_path}"
      Rails.logger.info "   Source exists: #{source_exists}"
      
      # Capture previous event context before any association changes
      @previous_event_id = event_id if instance_variable_get(:@previous_event_id).nil?
      
      result = false
      case target_state
      when :unsorted
        Rails.logger.info "   📁 Moving to UNSORTED"
        result = move_file_to_unsorted(source_path)
      when :daily
        Rails.logger.info "   📁 Moving to DAILY"
        result = move_file_to_daily(source_path)
      when :event_root
        Rails.logger.info "   📁 Moving to EVENT_ROOT"
        target_event_id = @pending_event_id || event_id
        if target_event_id.present?
          target_event = Event.find_by(id: target_event_id)
          Rails.logger.info "   event_id present=#{target_event_id}, event_folder=#{target_event&.folder_name}"
          result = move_file_to_event(source_path)
        else
          Rails.logger.error "   ❌ Cannot move to event - no event_id set (pending: #{@pending_event_id.inspect}, current: #{event_id.inspect})"
          result = false
        end
      when :subevent_level1, :subevent_level2
        Rails.logger.info "   📁 Moving to SUBEVENT (#{target_state})"
        target_event_id = @pending_event_id || event_id
        target_subevent_id = @pending_subevent_id || subevent_id
        if target_subevent_id.present?
          target_subevent = Subevent.find_by(id: target_subevent_id)
          Rails.logger.info "   subevent_id present=#{target_subevent_id}, subevent_title=#{target_subevent&.title}"
          Rails.logger.info "   subevent_depth=#{target_subevent&.depth}, parent_subevent_id=#{target_subevent&.parent_subevent_id}"
          result = move_file_to_subevent(source_path)
        else
          Rails.logger.error "   ❌ Cannot move to subevent - no subevent_id set (pending: #{@pending_subevent_id.inspect}, current: #{subevent_id.inspect})"
          result = false
        end
      else
        Rails.logger.warn "   ❌ Unknown target state: #{target_state}"
        result = false
      end
      
      Rails.logger.info "   📁 [perform_file_move] Result: #{result ? '✅ SUCCESS' : '❌ FAILED'}"
      # Clear captured source path after use
      @source_path_before_move = nil
      result
    rescue => e
      Rails.logger.error "   ❌ [perform_file_move] Exception: #{e.class} - #{e.message}"
      Rails.logger.error "   Backtrace:"
      e.backtrace.first(10).each { |line| Rails.logger.error "      #{line}" }
      # Clear captured source path even on error
      @source_path_before_move = nil
      false
    end
  end
  
  # Move file to unsorted (only moves file, doesn't update DB)
  def move_file_to_unsorted
    # Ensure we have fresh DB values in case the event folder was renamed mid-batch
    reload
    source_path = full_file_path
    old_dir = File.dirname(source_path) if source_path && File.exist?(source_path) # Save old directory for cleanup
    dest_dir = Constants::UNSORTED_STORAGE
    
    FileUtils.mkdir_p(dest_dir) unless Dir.exist?(dest_dir)
    
    unless source_path && File.exist?(source_path)
      Rails.logger.warn "⚠️ move_file_to_unsorted: source missing at expected path, attempting fallback search. expected=#{source_path}"
      # Try to find by filename anywhere under storage roots
      candidates = Medium.search_for_file(current_filename)
      if candidates.any?
        source_path = candidates.first
        old_dir = File.dirname(source_path)
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
        Rails.logger.info "✅ File already at unsorted: #{dest_path}"
        return true
      end
      FileUtils.mv(source_path, dest_path)
      # Update in-memory attributes (persisted after transition)
      self.current_filename = File.basename(dest_path)
      Rails.logger.info "✅ Moved file to unsorted: #{dest_path}"
      # Clean up empty directories in source location
      cleanup_empty_directories(old_dir)
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
    
    date = effective_datetime
    year = date.year.to_s
    month = date.month.to_s.rjust(2, '0')
    day = date.day.to_s.rjust(2, '0')
    
    daily_dir = File.join(Constants::DAILY_STORAGE, year, month, day)
    new_path = File.join(daily_dir, current_filename)
    
    source_path = full_file_path
    old_dir = File.dirname(source_path) if source_path && File.exist?(source_path)
    FileUtils.mkdir_p(daily_dir) unless Dir.exist?(daily_dir)
    
    Rails.logger.info "daily: dest_dir=#{daily_dir} dest_path=#{new_path}"
    if File.exist?(source_path) && source_path != new_path
      Rails.logger.info "daily: moving #{source_path} -> #{new_path}"
      FileUtils.mv(source_path, new_path)
      # Update in-memory attributes (will be saved by AASM)
      Rails.logger.info "✅ Moved file to: #{new_path}"
      
      # Clean up empty directories in source location
      cleanup_empty_directories(old_dir)
      true
    else
      unless File.exist?(source_path)
        Rails.logger.error "❌ move_file_to_daily: source file missing: #{source_path}"
        return false
      end
      Rails.logger.info "daily: already at destination #{new_path}"
      # Already at destination
      true
    end
  end
  
  # Move file to event root (only moves file, doesn't update DB)
  def move_file_to_event(source_path = nil)
    Rails.logger.info "📁 [move_file_to_event] Medium #{id}: Starting event move"
    
    # Use instance variable to get destination - association not set yet
    target_event_id = @pending_event_id || event_id
    
    unless target_event_id.present?
      Rails.logger.error "   ❌ target_event_id is nil"
      return false
    end
    
    # Load event directly using ID (association not set yet)
    target_event = Event.find_by(id: target_event_id)
    
    unless target_event.present?
      Rails.logger.error "   ❌ Event (id: #{target_event_id}) not found"
      return false
    end
    
    Rails.logger.info "   Event: #{target_event.title} (id: #{target_event.id}, folder: #{target_event.folder_name})"
    
    # Use provided source_path or fall back to current full_file_path
    source_path ||= full_file_path
    source_exists = source_path.present? && File.exist?(source_path)
    Rails.logger.info "   Source path: #{source_path}"
    Rails.logger.info "   Source exists: #{source_exists}"
    
    old_dir = File.dirname(source_path) if source_path && source_exists
    
    event_dir = File.join(Constants::EVENTS_STORAGE, target_event.folder_name)
    Rails.logger.info "   Event dir: #{event_dir}"
    Rails.logger.info "   Events storage root: #{Constants::EVENTS_STORAGE}"
    
    new_path = File.join(event_dir, current_filename)
    Rails.logger.info "   Destination path: #{new_path}"
    
    # Check if directory exists, create if not
    if Dir.exist?(event_dir)
      Rails.logger.info "   ✅ Event directory already exists"
    else
      Rails.logger.info "   📂 Creating event directory: #{event_dir}"
      FileUtils.mkdir_p(event_dir)
      Rails.logger.info "   ✅ Created event directory"
    end
    
    if source_exists && source_path != new_path
      Rails.logger.info "   📦 Moving file: #{source_path} -> #{new_path}"
      begin
        FileUtils.mv(source_path, new_path)
        Rails.logger.info "   ✅ File moved successfully"
        
        # Update in-memory attributes (will be saved by AASM)
        Rails.logger.info "   ✅ Moved file to: #{new_path}"
        
        # Clean up empty directories in source location
        cleanup_empty_directories(old_dir)
        true
      rescue => e
        Rails.logger.error "   ❌ FileUtils.mv failed: #{e.class} - #{e.message}"
        Rails.logger.error "   Source: #{source_path}"
        Rails.logger.error "   Destination: #{new_path}"
        false
      end
    else
      unless source_exists
        Rails.logger.error "   ❌ Source file missing: #{source_path}"
        return false
      end
      if source_path == new_path
        Rails.logger.info "   ✅ Already at destination: #{new_path}"
        true
      else
        Rails.logger.warn "   ⚠️ Source exists but paths don't match. Source: #{source_path}, Dest: #{new_path}"
        false
      end
    end
  end
  
  # Move file to subevent (only moves file, doesn't update DB)
  def move_file_to_subevent(source_path = nil)
    Rails.logger.info "📁 [move_file_to_subevent] Medium #{id}: Starting subevent move"
    
    # Use instance variables to get destination - associations not set yet
    target_event_id = @pending_event_id || event_id
    target_subevent_id = @pending_subevent_id || subevent_id
    
    unless target_event_id.present?
      Rails.logger.error "   ❌ target_event_id is nil"
      return false
    end
    
    unless target_subevent_id.present?
      Rails.logger.error "   ❌ target_subevent_id is nil"
      return false
    end
    
    # Load event and subevent directly using IDs (associations not set yet)
    target_event = Event.find_by(id: target_event_id)
    target_subevent = Subevent.find_by(id: target_subevent_id)
    
    unless target_event.present?
      Rails.logger.error "   ❌ Event (id: #{target_event_id}) not found"
      return false
    end
    
    unless target_subevent.present?
      Rails.logger.error "   ❌ Subevent (id: #{target_subevent_id}) not found"
      return false
    end
    
    Rails.logger.info "   Event: #{target_event.title} (id: #{target_event.id}, folder: #{target_event.folder_name})"
    Rails.logger.info "   Subevent: #{target_subevent.title} (id: #{target_subevent.id})"
    Rails.logger.info "   Subevent parent_subevent_id: #{target_subevent.parent_subevent_id}"
    
    # Use provided source_path or fall back to current full_file_path
    source_path ||= full_file_path
    source_exists = source_path.present? && File.exist?(source_path)
    Rails.logger.info "   Source path: #{source_path}"
    Rails.logger.info "   Source exists: #{source_exists}"
    
    old_dir = File.dirname(source_path) if source_path && source_exists
    
    event_dir = File.join(Constants::EVENTS_STORAGE, target_event.folder_name)
    Rails.logger.info "   Event dir: #{event_dir}"
    Rails.logger.info "   Events storage root: #{Constants::EVENTS_STORAGE}"
    
    begin
      if target_subevent.parent_subevent_id.present?
        # Level 2 subevent
        parent = target_subevent.parent_subevent
        unless parent.present?
          Rails.logger.error "   ❌ Parent subevent (id: #{target_subevent.parent_subevent_id}) not found"
          return false
        end
        Rails.logger.info "   Level 2 subevent detected"
        Rails.logger.info "   Parent subevent: #{parent.title} (id: #{parent.id}, folder: #{parent.footer_name})"
        subevent_dir = File.join(event_dir, parent.footer_name, target_subevent.footer_name)
      else
        # Level 1 subevent
        Rails.logger.info "   Level 1 subevent detected"
        subevent_dir = File.join(event_dir, target_subevent.footer_name)
      end
      
      Rails.logger.info "   Subevent dir: #{subevent_dir}"
      
      new_path = File.join(subevent_dir, current_filename)
      Rails.logger.info "   Destination path: #{new_path}"
      
      # Check if directory exists, create if not
      if Dir.exist?(subevent_dir)
        Rails.logger.info "   ✅ Subevent directory already exists"
      else
        Rails.logger.info "   📂 Creating subevent directory: #{subevent_dir}"
        FileUtils.mkdir_p(subevent_dir)
        Rails.logger.info "   ✅ Created subevent directory"
      end
      
      if source_exists && source_path != new_path
        Rails.logger.info "   📦 Moving file: #{source_path} -> #{new_path}"
        begin
          FileUtils.mv(source_path, new_path)
          Rails.logger.info "   ✅ File moved successfully"
          
          # Update in-memory attributes (will be saved by AASM)
          Rails.logger.info "   ✅ Moved file to: #{new_path}"
          
          # Clean up empty directories in source location
          cleanup_empty_directories(old_dir)
          true
        rescue => e
          Rails.logger.error "   ❌ FileUtils.mv failed: #{e.class} - #{e.message}"
          Rails.logger.error "   Source: #{source_path}"
          Rails.logger.error "   Destination: #{new_path}"
          false
        end
      else
        unless source_exists
          Rails.logger.error "   ❌ Source file missing: #{source_path}"
          return false
        end
        if source_path == new_path
          Rails.logger.info "   ✅ Already at destination: #{new_path}"
          true
        else
          Rails.logger.warn "   ⚠️ Source exists but paths don't match. Source: #{source_path}, Dest: #{new_path}"
          false
        end
      end
    rescue => e
      Rails.logger.error "   ❌ [move_file_to_subevent] Exception: #{e.class} - #{e.message}"
      Rails.logger.error "   Backtrace:"
      e.backtrace.first(10).each { |line| Rails.logger.error "      #{line}" }
      false
    end
  end
  
  # Clean up empty directories after moving a file
  # Walks up the directory tree removing empty directories until hitting a storage root
  def cleanup_empty_directories(old_dir)
    return unless old_dir
    
    # Walk up the directory tree and remove empty directories
    dir_path = old_dir
    
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
    # Do NOT update self.event_id or self.subevent_id here - that happens in after callback
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
      Rails.logger.info "Validation passed - event exists. Will set event_id in after callback."
    elsif subevent_id_to_use.present?
      subevent = Subevent.find_by(id: subevent_id_to_use)
      unless subevent
        raise "Cannot transition to subevent state: subevent #{subevent_id_to_use} does not exist"
      end
      Rails.logger.info "Validation passed - subevent exists (depth: #{subevent.depth}), event_id: #{subevent.event_id}"
      Rails.logger.info "Will set subevent_id and event_id in after callback."
    else
      Rails.logger.info "No case matched - event_id_to_use: #{event_id_to_use.inspect}, subevent_id_to_use: #{subevent_id_to_use.inspect}"
    end
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
    Rails.logger.info "=== UPDATE ASSOCIATIONS ==="
    Rails.logger.info "@pending_event_id: #{@pending_event_id.inspect}"
    Rails.logger.info "@pending_subevent_id: #{@pending_subevent_id.inspect}"
    Rails.logger.info "aasm.to_state: #{aasm.to_state}"
    
    # Update event and subevent associations based on state
    # Use @pending_event_id and @pending_subevent_id if available (from before callback)
    case aasm.to_state
    when :unsorted, :daily
      self.event = nil
      self.subevent = nil
      Rails.logger.info "Set associations to nil for #{aasm.to_state}"
    when :event_root
      # Set event_id from instance variable if available
      if @pending_event_id.present?
        self.event_id = @pending_event_id
        Rails.logger.info "Set event_id to #{@pending_event_id} from @pending_event_id"
      end
      self.subevent = nil
      Rails.logger.info "Set subevent to nil for event_root"
    when :subevent_level1, :subevent_level2
      # Set subevent_id and event_id from instance variables if available
      if @pending_subevent_id.present?
        self.subevent_id = @pending_subevent_id
        Rails.logger.info "Set subevent_id to #{@pending_subevent_id} from @pending_subevent_id"
        
        # Get event_id from subevent if not already set
        if subevent.present? && (event_id.blank? || @pending_event_id.present?)
          target_event_id = @pending_event_id || subevent.event_id
          if target_event_id.present?
            self.event_id = target_event_id
            Rails.logger.info "Set event_id to #{target_event_id} from subevent"
          end
        end
      elsif @pending_event_id.present?
        # Just setting event_id
        self.event_id = @pending_event_id
        Rails.logger.info "Set event_id to #{@pending_event_id} from @pending_event_id"
      end
      Rails.logger.info "Final associations: event_id=#{event_id}, subevent_id=#{subevent_id}"
    end
    
    # Clear instance variables after use
    @pending_event_id = nil
    @pending_subevent_id = nil
    Rails.logger.info "=== END UPDATE ASSOCIATIONS ==="
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
    target_event_id = @pending_event_id || event_id
    
    # Safety check: target event must exist
    if target_event_id.present?
      unless Event.exists?(id: target_event_id)
        Rails.logger.warn "AASM Guard: Cannot move to event - target event #{target_event_id} does not exist"
        @guard_failure_reason = "target event does not exist"
        return false
      end
    else
      # No target event specified
      Rails.logger.warn "AASM Guard: Cannot move to event - no target event specified"
      @guard_failure_reason = "no target event specified"
      return false
    end
    
    # Check that destination is different from source
    # If source is in event tree, check that we're moving to a different event
    if event_id.present?
      if event_id == target_event_id && subevent_id.blank?
        Rails.logger.warn "AASM Guard: Cannot move to event - already in event #{target_event_id}"
        @guard_failure_reason = "already in this event"
        return false
      end
    end
    
    Rails.logger.debug "AASM Guard: Can move to event #{target_event_id}"
    true
  end

  # Consolidated guard for moving to any subevent (SL1 or SL2)
  # The only difference is validating the target subevent's level matches the target state
  def can_move_to_subevent?(expected_level: nil)
    Rails.logger.info "🛡️ [can_move_to_subevent] Medium #{id || 'new'}: Starting guard check"
    Rails.logger.info "   Expected level: #{expected_level.inspect}"
    Rails.logger.info "   Current state: #{aasm.current_state}"
    Rails.logger.info "   Current event_id: #{event_id}, subevent_id: #{subevent_id}"
    Rails.logger.info "   @pending_event_id: #{@pending_event_id}, @pending_subevent_id: #{@pending_subevent_id}"
    
    target_subevent_id = @pending_subevent_id || subevent_id
    target_event_id = @pending_event_id || event_id
    
    Rails.logger.info "   Target subevent_id: #{target_subevent_id}, target_event_id: #{target_event_id}"
    
    # Safety check: target subevent must exist
    if target_subevent_id.present?
      target_subevent = Subevent.find_by(id: target_subevent_id)
      unless target_subevent
        Rails.logger.warn "   ❌ AASM Guard: Cannot move to subevent - target subevent #{target_subevent_id} does not exist"
        @guard_failure_reason = "target subevent does not exist"
        return false
      end
      
      Rails.logger.info "   ✅ Target subevent found: #{target_subevent.title} (id: #{target_subevent_id})"
      Rails.logger.info "   Target subevent event_id: #{target_subevent.event_id}, parent_subevent_id: #{target_subevent.parent_subevent_id}"
      
      # Safety check: validate level if expected_level is specified
      if expected_level.present?
        is_level2 = target_subevent.parent_subevent_id.present?
        Rails.logger.info "   Checking level: expected=#{expected_level}, actual=#{is_level2 ? 'level2' : 'level1'}"
        if expected_level == :level1 && is_level2
          Rails.logger.warn "   ❌ AASM Guard: Cannot move to subevent level 1 - target subevent #{target_subevent_id} is level 2 (has parent)"
          @guard_failure_reason = "target subevent is not level 1"
          return false
        elsif expected_level == :level2 && !is_level2
          Rails.logger.warn "   ❌ AASM Guard: Cannot move to subevent level 2 - target subevent #{target_subevent_id} is level 1 (no parent)"
          @guard_failure_reason = "target subevent is not level 2"
          return false
        end
        Rails.logger.info "   ✅ Level check passed"
      end
    else
      Rails.logger.warn "   ❌ AASM Guard: Cannot move to subevent - no target subevent specified"
      @guard_failure_reason = "no target subevent specified"
      return false
    end
    
    # Check that destination is different from source
    # If source is in event tree (not daily/unsorted), check that destination differs
    if event_id.present? || subevent_id.present?
      source_event_id = event_id || (subevent_id.present? ? Subevent.find_by(id: subevent_id)&.event_id : nil)
      Rails.logger.info "   Checking differentiation: source_event_id=#{source_event_id}, target_event_id=#{target_event_id}"
      Rails.logger.info "   source_subevent_id=#{subevent_id}, target_subevent_id=#{target_subevent_id}"
      if source_event_id == target_event_id && subevent_id == target_subevent_id
        Rails.logger.warn "   ❌ AASM Guard: Cannot move to subevent - already in subevent #{target_subevent_id}"
        @guard_failure_reason = "already in this subevent"
        return false
      end
      Rails.logger.info "   ✅ Differentiation check passed - destination differs from source"
    else
      Rails.logger.info "   ✅ Source is daily/unsorted - destination check not needed"
    end
    
    Rails.logger.info "   ✅ AASM Guard: Can move to subevent - target subevent #{target_subevent_id} is valid"
    true
  end

  # Wrapper methods for backwards compatibility with AASM guard references
  def can_move_to_subevent_level1?
    Rails.logger.info "🛡️ [can_move_to_subevent_level1] Medium #{id || 'new'}: Wrapper called"
    can_move_to_subevent?(expected_level: :level1)
  end

  def can_move_to_subevent_level2?
    Rails.logger.info "🛡️ [can_move_to_subevent_level2] Medium #{id || 'new'}: Wrapper called"
    can_move_to_subevent?(expected_level: :level2)
  end
end