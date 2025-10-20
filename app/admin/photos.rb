ActiveAdmin.register Photo do

  # Permitted parameters
  permit_params :title, :description, :file_path, :file_size, :width, :height, 
                :exif_data, :thumbnail_path, :thumbnail_width, 
                :thumbnail_height, :uploaded_by_id, :user_id, :original_filename, 
                :content_type, :md5_hash, :latitude, :longitude, :camera_make, :camera_model

  # Index page configuration
  index do
    selectable_column
    id_column
    
    column :title
    column :original_filename
    column :user
    column :uploaded_by
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
    column :camera_make
    column :camera_model
    column "Location" do |photo|
      if photo.has_location?
        "#{photo.latitude}, #{photo.longitude}"
      else
        "No location"
      end
    end
    column :created_at
    
    actions
  end

  # Filters
  filter :title
  filter :original_filename
  filter :user
  filter :uploaded_by
  filter :effective_datetime
  filter :camera_make
  filter :camera_model
  filter :content_type, as: :select, collection: %w[image/jpeg image/png image/gif image/bmp image/tiff]
  filter :created_at

  # Show page configuration
  show do
    attributes_table do
      row :id
      row :title
      row :description
      row :original_filename
      row :file_path
      row :content_type
      row :file_size do |photo|
        photo.file_size_human
      end
      row :dimensions do |photo|
        "#{photo.width} × #{photo.height} pixels"
      end
      row :thumbnail_dimensions do |photo|
        if photo.thumbnail_width && photo.thumbnail_height
          "#{photo.thumbnail_width} × #{photo.thumbnail_height} pixels"
        else
          "Not generated"
        end
      end
      row :effective_datetime do |photo|
        if photo.effective_datetime
          content_tag :div, photo.effective_datetime.strftime("%Y-%m-%d %H:%M:%S"), style: "font-weight: bold;"
        else
          content_tag :div, "No date available", style: "color: #cc0000; font-weight: bold;"
        end
      end
      row :user
      row :uploaded_by
      row :camera_make
      row :camera_model
      row :location do |photo|
        if photo.has_location?
          "#{photo.latitude}, #{photo.longitude}"
        else
          "No location data"
        end
      end
      row :md5_hash
      row :created_at
      row :updated_at
      
      row :albums do |photo|
        photo.albums.map(&:title).join(", ")
      end
    end

    panel "EXIF Data" do
      if photo.exif_data.present?
        table_for photo.exif_data.to_a do
          column("Property") { |item| item[0] }
          column("Value") { |item| item[1] }
        end
      else
        "No EXIF data available"
      end
    end
  end

  # Form configuration
  form do |f|
    f.inputs "Photo Details" do
      f.input :title
      f.input :description
      f.input :file_path
      f.input :original_filename
      f.input :content_type, as: :select, collection: %w[image/jpeg image/png image/gif image/bmp image/tiff]
      f.input :user
      f.input :uploaded_by, as: :select, collection: User.all
    end

    f.inputs "Dimensions" do
      f.input :width
      f.input :height
      f.input :file_size, hint: "Size in bytes"
    end

    f.inputs "Metadata" do
      f.input :effective_datetime, as: :datetime_picker, label: "Effective Date/Time"
      f.input :camera_make
      f.input :camera_model
      f.input :latitude
      f.input :longitude
    end

    f.actions
  end

  # Custom controller actions
  controller do
    def show
      @photo = Photo.find(params[:id])
      show! # This calls the default show action
    end
  end

end
