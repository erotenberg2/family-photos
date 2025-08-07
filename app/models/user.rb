class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Constants
  ROLES = Config::FAMILY_ROLES

  # Associations
  has_many :uploaded_photos, class_name: 'Photo', foreign_key: 'uploaded_by_id', dependent: :destroy
  has_many :owned_photos, class_name: 'Photo', dependent: :destroy
  has_many :created_albums, class_name: 'Album', foreign_key: 'created_by_id', dependent: :destroy
  has_many :owned_albums, class_name: 'Album', dependent: :destroy

  # Validations
  validates :first_name, presence: true, length: { minimum: 1, maximum: 50 }
  validates :last_name, presence: true, length: { minimum: 1, maximum: 50 }
  validates :role, presence: true, inclusion: { 
    in: ROLES,
    message: 'must be a valid role'
  }
  validates :active, inclusion: { in: [true, false] }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_role, ->(role) { where(role: role) }
  scope :family_members, -> { where(role: 'family_member') }
  scope :photo_admins, -> { where(role: 'photo_admin') }
  scope :family_admins, -> { where(role: 'family_admin') }
  scope :by_name, -> { order(:first_name, :last_name) }

  # Role checking methods
  def family_member?
    role == 'family_member'
  end

  def photo_admin?
    role == 'photo_admin'
  end

  def family_admin?
    role == 'family_admin'
  end

  # Class methods for roles
  def self.roles_for_select
    ROLES.map { |role| [role.humanize.titleize, role] }
  end

  def admin_level?
    photo_admin? || family_admin?
  end

  # Permission methods
  def can_upload_photos?
    active? && (family_member? || admin_level?)
  end

  def can_create_albums?
    active? && (photo_admin? || family_admin?)
  end

  def can_manage_users?
    active? && family_admin?
  end

  def can_delete_photos?
    active? && admin_level?
  end

  def can_edit_photo?(photo)
    return false unless active?
    return true if family_admin?
    return true if photo_admin?
    return true if photo.uploaded_by == self || photo.user == self
    false
  end

  def can_view_album?(album)
    return false unless active?
    return true unless album.private?
    return true if album.user == self || album.created_by == self
    return true if admin_level?
    false
  end

  # Display methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.present? ? full_name : email
  end

  def role_display
    role.humanize.titleize
  end

  def status_display
    active? ? 'Active' : 'Inactive'
  end

  # Stats methods
  def photo_count
    uploaded_photos.count
  end

  def album_count
    owned_albums.count
  end

  def storage_used
    uploaded_photos.sum(:file_size)
  end

  def storage_used_human
    return '0 B' if storage_used.nil? || storage_used.zero?
    
    units = %w[B KB MB GB TB]
    size = storage_used.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    "#{size.round(1)} #{units[unit_index]}"
  end

  # Class methods
  def self.total_users
    count
  end

  def self.active_users
    active.count
  end

  def self.total_storage_used
    joins(:uploaded_photos).sum('photos.file_size')
  end

  # Ransack configuration for Active Admin
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "email", "encrypted_password", "id", "remember_created_at", 
     "reset_password_sent_at", "reset_password_token", "updated_at", "first_name", 
     "last_name", "role", "active"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["uploaded_photos", "owned_photos", "created_albums", "owned_albums"]
  end

  private

  # Override Devise method to prevent inactive users from signing in
  def active_for_authentication?
    super && active?
  end

  # Custom message for inactive users
  def inactive_message
    active? ? super : :account_inactive
  end
end
