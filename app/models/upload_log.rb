class UploadLog < ApplicationRecord
  belongs_to :user
  
  # Validations
  validates :batch_id, presence: true, uniqueness: true
  validates :session_id, presence: true
  validates :completion_status, presence: true, inclusion: { in: %w[incomplete complete interrupted] }
  validates :total_files_selected, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :files_imported, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :files_skipped, presence: true, numericality: { greater_than_or_equal_to: 0 }
  # files_data can be empty array initially, will be populated during upload
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where.not(session_completed_at: nil) }
  scope :in_progress, -> { where(session_completed_at: nil) }
  scope :by_user, ->(user) { where(user: user) }
  scope :successful, -> { where('files_imported > 0') }
  scope :with_errors, -> { where('files_skipped > 0') }
  scope :stale, -> { where(session_completed_at: nil).where('session_started_at < ?', 1.hour.ago) }
  scope :interrupted, -> { where(completion_status: 'interrupted') }
  scope :complete_status, -> { where(completion_status: 'complete') }
  scope :incomplete_status, -> { where(completion_status: 'incomplete') }
  
  # Ransackable attributes for ActiveAdmin filtering
  def self.ransackable_attributes(auth_object = nil)
    ["batch_id", "completion_status", "created_at", "files_imported", "files_skipped", "session_completed_at", 
     "session_id", "session_started_at", "total_files_selected", "updated_at", 
     "user_agent", "user_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["user"]
  end
  
  # Helper methods
  def session_duration
    return nil unless session_started_at && session_completed_at
    session_completed_at - session_started_at
  end
  
  def session_duration_human
    duration = session_duration
    return "—" unless duration
    
    if duration < 60
      "#{duration.round(1)}s"
    else
      minutes = (duration / 60).floor
      seconds = (duration % 60).round
      "#{minutes}m #{seconds}s"
    end
  end
  
  def status
    case completion_status
    when 'interrupted'
      return 'Interrupted'
    when 'incomplete'
      return 'In Progress'
    when 'complete'
      return 'Success' if files_skipped == 0 && files_imported > 0
      return 'Partial Success' if files_imported > 0 && files_skipped > 0
      return 'All Failed' if files_imported == 0 && files_skipped > 0
      return 'Complete'
    else
      'Unknown'
    end
  end
  
  def status_color
    case status
    when 'Success' then 'green'
    when 'Partial Success' then 'orange'
    when 'All Failed' then 'red'
    when 'In Progress' then 'blue'
    when 'Interrupted' then 'purple'
    when 'Complete' then 'green'
    else 'gray'
    end
  end
  
  def success_rate
    return 0 if total_files_selected == 0
    (files_imported.to_f / total_files_selected * 100).round(1)
  end
  
  def browser_name
    return "Unknown" unless user_agent.present?
    
    case user_agent
    when /Chrome/i then "Chrome"
    when /Firefox/i then "Firefox"
    when /Safari/i then "Safari"
    when /Edge/i then "Edge"
    else "Other"
    end
  end
  
  # Get imported files with their medium/mediable info for linking
  def imported_files
    files_data.select { |file| file['status'] == 'imported' }
  end
  
  # Get skipped files with their skip reasons
  def skipped_files
    files_data.select { |file| file['status'] == 'skipped' }
  end
  
  # Add a file to the files_data array
  def add_file_data(filename:, file_size:, content_type:, status:, skip_reason: nil, medium: nil, client_file_path: nil)
    file_data = {
      filename: filename,
      file_size: file_size,
      content_type: content_type,
      status: status,
      skip_reason: skip_reason,
      client_file_path: client_file_path
    }
    
    # Add medium/mediable info if successfully imported
    if medium && status == 'imported'
      file_data.merge!(
        medium_id: medium.id,
        medium_type: medium.medium_type,
        mediable_id: medium.mediable&.id,
        mediable_type: medium.mediable&.class&.name
      )
    end
    
    self.files_data = (files_data || []) + [file_data]
    save!
  end
  
  # Update summary statistics
  def update_statistics!
    self.total_files_selected = files_data.length
    self.files_imported = files_data.count { |f| f['status'] == 'imported' }
    self.files_skipped = files_data.count { |f| f['status'] == 'skipped' }
    save!
  end
  
  # Auto-complete stale upload sessions (called by background job or rake task)
  def self.auto_complete_stale_sessions!
    stale_sessions = stale.includes(:user)
    
    stale_sessions.each do |session|
      Rails.logger.info "Auto-completing stale upload session: #{session.session_id} for user: #{session.user.email}"
      session.update!(
        session_completed_at: Time.current,
        completion_status: 'interrupted'
        # Note: files_imported and files_skipped should already be accurate from batch updates
      )
    end
    
    stale_sessions.count
  end
end
