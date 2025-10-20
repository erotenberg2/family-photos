ActiveAdmin.register Album do

  # Permitted parameters
  permit_params :title, :description, :cover_photo_id, :user_id, :private, :created_by_id

  # Index page configuration
  index do
    selectable_column
    id_column
    
    column :title
    column :description do |album|
      truncate(album.description, length: 100) if album.description
    end
    column :user
    column :created_by
    column "Photos" do |album|
      album.photo_count
    end
    column "Cover Photo" do |album|
      if album.cover_photo
        album.cover_photo.title || album.cover_photo.original_filename
      else
        "No cover"
      end
    end
    column :private do |album|
      album.private? ? "Private" : "Public"
    end
    column "Total Size" do |album|
      number_to_human_size(album.total_file_size)
    end
    column :created_at
    
    actions
  end

  # Filters
  filter :title
  filter :user
  filter :created_by
  filter :private
  filter :created_at

  # Show page configuration
  show do
    attributes_table do
      row :id
      row :title
      row :description
      row :user
      row :created_by
      row :private do |album|
        album.private? ? "Private" : "Public"
      end
      row :cover_photo do |album|
        if album.cover_photo
          link_to album.cover_photo.title || album.cover_photo.original_filename, 
                  admin_photo_path(album.cover_photo)
        else
          "No cover photo set"
        end
      end
      row :photo_count
      row :total_file_size do |album|
        number_to_human_size(album.total_file_size)
      end
      row :date_range do |album|
        range = album.date_range
        if range
          "#{range[:start_date].strftime('%B %d, %Y')} - #{range[:end_date].strftime('%B %d, %Y')}"
        else
          "No photos with dates"
        end
      end
      row :created_at
      row :updated_at
    end

    panel "Photos in Album" do
      if album.photos.any?
        table_for album.ordered_photos do
          column "Position" do |photo|
            album.photo_albums.find_by(photo: photo)&.position
          end
          column :title do |photo|
            link_to photo.title || photo.original_filename, admin_photo_path(photo)
          end
          column :original_filename
          column :effective_datetime do |photo|
            if photo.effective_datetime
              content_tag :div, photo.effective_datetime.strftime("%Y-%m-%d %H:%M"), 
                          title: "Source: #{photo.datetime_source}"
            else
              content_tag :div, "No date", style: "color: #999;"
            end
          end
          column "Size" do |photo|
            "#{photo.width}×#{photo.height}"
          end
          column "File Size" do |photo|
            photo.file_size_human
          end
        end
      else
        "No photos in this album"
      end
    end
  end

  # Form configuration
  form do |f|
    f.inputs "Album Details" do
      f.input :title
      f.input :description
      f.input :user, as: :select, collection: User.all
      f.input :created_by, as: :select, collection: User.all
      f.input :private, as: :boolean, hint: "Private albums are only visible to the owner"
    end

    f.inputs "Cover Photo" do
      f.input :cover_photo, as: :select, 
              collection: Photo.all.map { |p| [p.title || p.original_filename, p.id] },
              include_blank: "No cover photo"
    end

    f.actions
  end

  # Custom controller actions
  controller do
    def show
      @album = Album.find(params[:id])
      show! # This calls the default show action
    end
  end

end
