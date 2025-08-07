ActiveAdmin.register User do

  # Permitted parameters
  permit_params :email, :password, :password_confirmation, :first_name, :last_name, :role, :active

  # Index page configuration
  index do
    selectable_column
    id_column
    
    column :email
    column :full_name
    column :role do |user|
      user.role_display
    end
    column :active do |user|
      user.status_display
    end
    column "Photos" do |user|
      user.uploaded_photos.count
    end
    column "Albums" do |user|
      user.owned_albums.count
    end
    column "Storage Used" do |user|
      user.storage_used_human
    end
    column :created_at
    
    actions
  end

  # Filters
  filter :email
  filter :first_name
  filter :last_name
  filter :role, as: :select, collection: %w[family_member photo_admin family_admin]
  filter :active
  filter :created_at

  # Show page configuration
  show do
    attributes_table do
      row :id
      row :email
      row :first_name
      row :last_name
      row :full_name
      row :role do |user|
        user.role_display
      end
      row :active do |user|
        user.status_display
      end
      row :created_at
      row :updated_at

      
      # Statistics
      row :photo_count do |user|
        user.uploaded_photos.count
      end
      row :album_count do |user|
        user.owned_albums.count
      end
      row :storage_used do |user|
        user.storage_used_human
      end
    end

    panel "Permissions" do
      attributes_table_for user do
        row "Can Upload Photos" do |u|
          u.can_upload_photos? ? "Yes" : "No"
        end
        row "Can Create Albums" do |u|
          u.can_create_albums? ? "Yes" : "No"
        end
        row "Can Manage Users" do |u|
          u.can_manage_users? ? "Yes" : "No"
        end
        row "Can Delete Photos" do |u|
          u.can_delete_photos? ? "Yes" : "No"
        end
      end
    end

    panel "Recent Photos" do
      if user.uploaded_photos.any?
        table_for user.uploaded_photos.recent.limit(10) do
          column :title do |photo|
            link_to photo.title || photo.original_filename, admin_photo_path(photo)
          end
          column :original_filename
          column :taken_at
          column :file_size do |photo|
            photo.file_size_human
          end
          column :created_at
        end
        
        if user.uploaded_photos.count > 10
          div do
            link_to "View all #{user.uploaded_photos.count} photos", 
                    admin_photos_path(q: { uploaded_by_id_eq: user.id })
          end
        end
      else
        "No photos uploaded yet"
      end
    end

    panel "Albums" do
      if user.owned_albums.any?
        table_for user.owned_albums.recent do
          column :title do |album|
            link_to album.title, admin_album_path(album)
          end
          column :description do |album|
            truncate(album.description, length: 100) if album.description
          end
          column :photo_count
          column :private do |album|
            album.private? ? "Private" : "Public"
          end
          column :created_at
        end
      else
        "No albums created yet"
      end
    end
  end

  # Form configuration
  form do |f|
    f.inputs "User Details" do
      f.input :email
      f.input :first_name
      f.input :last_name
      f.input :role, as: :select, 
              collection: [
                ['Family Member', 'family_member'],
                ['Photo Admin', 'photo_admin'],
                ['Family Admin', 'family_admin']
              ],
              include_blank: false,
              hint: "Family Member: Can upload photos. Photo Admin: Can manage photos and albums. Family Admin: Can manage users and all content."
      f.input :active, as: :boolean, hint: "Inactive users cannot sign in"
    end

    f.inputs "Password" do
      f.input :password, hint: "Leave blank to keep current password"
      f.input :password_confirmation
    end

    f.actions
  end

  # Custom actions
  action_item :activate, only: :show, if: proc { !user.active? } do
    link_to "Activate User", activate_admin_user_path(user), method: :patch, 
            confirm: "Are you sure you want to activate this user?"
  end

  action_item :deactivate, only: :show, if: proc { user.active? } do
    link_to "Deactivate User", deactivate_admin_user_path(user), method: :patch, 
            confirm: "Are you sure you want to deactivate this user?"
  end

  # Member actions
  member_action :activate, method: :patch do
    resource.update!(active: true)
    redirect_to admin_user_path(resource), notice: "User has been activated"
  end

  member_action :deactivate, method: :patch do
    resource.update!(active: false)
    redirect_to admin_user_path(resource), notice: "User has been deactivated"
  end

  # Collection actions for bulk operations
  batch_action :activate do |ids|
    User.where(id: ids).update_all(active: true)
    redirect_to collection_path, notice: "#{ids.count} users have been activated"
  end

  batch_action :deactivate do |ids|
    User.where(id: ids).update_all(active: false)
    redirect_to collection_path, notice: "#{ids.count} users have been deactivated"
  end

  # Controller customizations
  controller do
    def show
      @user = User.find(params[:id])
      show! # This calls the default show action
    end

    def update
      if params[:user][:password].blank?
        params[:user].delete(:password)
        params[:user].delete(:password_confirmation)
      end
      super
    end
  end

end
