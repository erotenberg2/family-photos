class Subevent < ApplicationRecord
  belongs_to :event
  belongs_to :parent_subevent, class_name: 'Subevent', optional: true
  has_many :child_subevents, class_name: 'Subevent', foreign_key: 'parent_subevent_id', dependent: :destroy
  has_many :media, dependent: :nullify
  
  validates :title, presence: true
  validate :depth_within_limit
  validate :no_self_reference
  validate :no_circular_reference
  
  # Callbacks for folder management
  after_create :set_initial_folder_path
  after_update :rename_subevent_folder, if: :saved_change_to_title?
  
  scope :top_level, -> { where(parent_subevent: nil) }
  scope :by_title, -> { order(:title) }
  
  def hierarchy_path
    return title if parent_subevent.nil?
    "#{parent_subevent.hierarchy_path} > #{title}"
  end
  
  def footer_name
    # Preserve the original case for the title, just clean up special characters
    title.gsub(/[^a-zA-Z0-9\s-]/, '').strip.gsub(/\s+/, '_')
  end
  
  def media_count
    media.count
  end
  
  def all_media
    # Get media from this subevent and all child subevents
    media_ids = media.pluck(:id)
    child_subevents.each do |child|
      media_ids += child.all_media.pluck(:id)
    end
    Medium.where(id: media_ids)
  end
  
  def depth
    return 1 if parent_subevent.nil?
    parent_subevent.depth + 1
  end
  
  def max_depth_reached?
    depth >= Constants::EVENT_RECURSION_DEPTH
  end
  
  def can_have_children?
    !max_depth_reached?
  end
  
  def ancestry
    ancestors = []
    current = self
    while current.parent_subevent
      current = current.parent_subevent
      ancestors << current
    end
    ancestors.reverse
  end
  
  private
  
  def depth_within_limit
    return unless parent_subevent
    
    if depth > Constants::EVENT_RECURSION_DEPTH
      errors.add(:parent_subevent, "would exceed maximum depth of #{Constants::EVENT_RECURSION_DEPTH} levels")
    end
  end
  
  def no_self_reference
    if parent_subevent_id && parent_subevent_id == id
      errors.add(:parent_subevent, "cannot be itself")
    end
  end
  
  def no_circular_reference
    return unless parent_subevent_id
    
    # Check if this subevent would create a circular reference
    current = parent_subevent
    while current
      if current.id == id
        errors.add(:parent_subevent, "would create a circular reference")
        break
      end
      current = current.parent_subevent
    end
  end
  
  # Ransackable attributes for ActiveAdmin filtering
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "description", "id", "title", "updated_at", "event_id", "parent_subevent_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["child_subevents", "event", "media", "parent_subevent"]
  end
  
  def rename_subevent_folder
    Rails.logger.info "=== SUBEVENT FOLDER RENAME CALLBACK TRIGGERED ==="
    Rails.logger.info "Subevent ID: #{id}"
    Rails.logger.info "Title changed from: '#{title_before_last_save}' to '#{title}'"
    Rails.logger.info "Current folder_path: '#{folder_path}'"
    
    return unless event.folder_path.present? && folder_path.present?
    
    require_relative '../../lib/constants'
    
    # Use the stored folder_path as the old path
    event_dir = File.join(Constants::EVENTS_STORAGE, event.folder_path)
    old_path = File.join(event_dir, folder_path)
    new_folder_name = footer_name
    new_path = File.join(event_dir, new_folder_name)
    
    Rails.logger.info "Event folder_path: '#{event.folder_path}'"
    Rails.logger.info "Old subevent folder_path: '#{folder_path}'"
    Rails.logger.info "New folder name: '#{new_folder_name}'"
    Rails.logger.info "Old path: #{old_path}"
    Rails.logger.info "New path: #{new_path}"
    Rails.logger.info "Old path exists: #{Dir.exist?(old_path)}"
    Rails.logger.info "Paths are different: #{old_path != new_path}"
    
    # Only rename if the folder exists and the name actually changed
    if Dir.exist?(old_path) && old_path != new_path
      begin
        Rails.logger.info "Attempting to rename subevent folder..."
        FileUtils.mv(old_path, new_path)
        Rails.logger.info "✅ Successfully renamed subevent folder from '#{folder_path}' to '#{new_folder_name}' in event '#{event.title}'"
        
        # Update the folder_path in the database
        update_column(:folder_path, new_folder_name)
        
        # Update file paths for all associated media
        update_media_file_paths(folder_path, new_folder_name)
      rescue => e
        Rails.logger.error "❌ Failed to rename subevent folder from '#{folder_path}' to '#{new_folder_name}': #{e.message}"
        Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
      end
    else
      Rails.logger.warn "⚠️ Skipping subevent rename - Old path doesn't exist or paths are the same"
      Rails.logger.warn "Old path exists: #{Dir.exist?(old_path)}"
      Rails.logger.warn "Paths different: #{old_path != new_path}"
    end
    
    Rails.logger.info "=== END SUBEVENT FOLDER RENAME CALLBACK ==="
  end
  
  def update_media_file_paths(old_folder_name, new_folder_name)
    # Update file paths for all media in this subevent
    media.each do |medium|
      if medium.file_path&.include?(old_folder_name)
        new_file_path = medium.file_path.gsub(old_folder_name, new_folder_name)
        medium.update_column(:file_path, new_file_path)
        Rails.logger.debug "Updated file path for Medium #{medium.id}: #{new_file_path}"
      end
    end
  end
  
  def set_initial_folder_path
    return unless title.present?
    
    Rails.logger.info "=== SETTING INITIAL SUBEVENT FOLDER PATH ==="
    Rails.logger.info "Subevent ID: #{id}"
    Rails.logger.info "Title: '#{title}'"
    
    folder_name_value = footer_name
    Rails.logger.info "Generated folder name: '#{folder_name_value}'"
    
    update_column(:folder_path, folder_name_value)
    Rails.logger.info "✅ Set subevent folder_path to: '#{folder_name_value}'"
    Rails.logger.info "=== END SETTING INITIAL SUBEVENT FOLDER PATH ==="
  end
end
