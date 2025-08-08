ActiveAdmin.register Photo, namespace: :family do

  # Add custom action button to index page
  action_item :import_photos, only: :index do
    link_to 'Import Photos', import_photos_family_photos_path, class: 'btn btn-primary'
  end

  # Permitted parameters
  permit_params :title, :description, :file_path, :file_size, :width, :height, 
                :taken_at, :exif_data, :thumbnail_path, :thumbnail_width, 
                :thumbnail_height, :uploaded_by_id, :user_id, :original_filename, 
                :content_type, :md5_hash, :latitude, :longitude, :camera_make, :camera_model

  # Index page configuration
  index do
    selectable_column
    
    column "Thumbnail", sortable: false do |photo|
      link_to family_photo_path(photo) do
        if photo.thumbnail_path && File.exist?(photo.thumbnail_path)
          image_tag("data:image/#{photo.content_type.split('/').last};base64,#{Base64.encode64(File.read(photo.thumbnail_path))}", 
                    style: "max-width: 60px; max-height: 60px; object-fit: cover; border-radius: 4px; cursor: pointer; transition: transform 0.2s ease; display: block;",
                    alt: photo.title || photo.original_filename,
                    onmouseover: "this.style.transform='scale(1.05)'",
                    onmouseout: "this.style.transform='scale(1)'")
        elsif photo.file_path && File.exist?(photo.file_path)
          # Fallback to original image if thumbnail doesn't exist
          image_tag("data:image/#{photo.content_type.split('/').last};base64,#{Base64.encode64(File.read(photo.file_path))}", 
                    style: "max-width: 60px; max-height: 60px; object-fit: cover; border-radius: 4px; cursor: pointer; transition: transform 0.2s ease; display: block;",
                    alt: photo.title || photo.original_filename,
                    onmouseover: "this.style.transform='scale(1.05)'",
                    onmouseout: "this.style.transform='scale(1)'")
        else
          content_tag :div, "No image", style: "width: 60px; height: 60px; background: #f0f0f0; display: flex; align-items: center; justify-content: center; font-size: 10px; color: #666; border-radius: 4px; cursor: pointer;"
        end
      end
    end
    
    column :title
    column :original_filename
    column :user
    column :uploaded_by
    column :taken_at
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
  filter :taken_at
  filter :camera_make
  filter :camera_model
  filter :content_type, as: :select, collection: %w[image/jpeg image/png image/gif image/bmp image/tiff image/heic image/heif]
  filter :created_at

  # Show page configuration
  show do
    # Add CSS for hover effects
    content_for :head do
      raw <<~CSS
        <style>
          .photo-thumbnail-link:hover img {
            box-shadow: 0 4px 12px rgba(0,0,0,0.2) !important;
            transform: scale(1.02);
          }
          .photo-thumbnail-link img {
            transition: all 0.3s ease !important;
          }
        </style>
      CSS
    end

    # Photo preview panel
    panel "Photo Preview" do
      if photo.thumbnail_path && File.exist?(photo.thumbnail_path)
        link_to image_tag("data:image/jpg;base64,#{Base64.encode64(File.read(photo.thumbnail_path))}", 
                  style: "max-width: 400px; max-height: 400px; object-fit: contain; border: 1px solid #ddd; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); display: block; margin: 0 auto;",
                  alt: photo.title || photo.original_filename), image_path(photo), target: "_blank"
      else
        div "Thumbnail not available", style: "padding: 40px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
      end
    end

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
      row :taken_at
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
        div do
          h4 "Formatted EXIF Data"
          pre JsonFormatterService.pretty_format(photo.exif_data), 
              style: "background: #f8f8f8; padding: 15px; border-radius: 5px; overflow-x: auto; font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace; font-size: 12px; line-height: 1.4; border: 1px solid #e0e0e0; white-space: pre-wrap;"
        end
        
        div style: "margin-top: 20px;" do
          h4 "EXIF Properties Table"
          table_for photo.exif_data.to_a do
            column("Property") { |item| item[0] }
            column("Value") { |item| item[1] }
          end
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
      f.input :taken_at, as: :datetime_picker
      f.input :camera_make
      f.input :camera_model
      f.input :latitude
      f.input :longitude
    end

    f.actions
  end

  # Collection actions
  collection_action :import_photos, method: [:get, :post] do
    if request.post?
      # Handle the photo import using background job
      if params[:photos].present?
        # Save uploaded files to temporary location and prepare data for the job
        uploaded_files_data = []
        temp_dir = Rails.root.join('tmp', 'photo_uploads')
        FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)
        
        params[:photos].each do |photo_param|
          file = photo_param[:file]
          next unless file.present?
          
          # Save to temporary file
          temp_filename = "#{SecureRandom.hex(16)}_#{file.original_filename}"
          temp_path = temp_dir.join(temp_filename)
          
          File.open(temp_path, 'wb') do |f|
            f.write(file.read)
          end
          
          # Store JSON-safe file data
          uploaded_files_data << {
            'original_filename' => file.original_filename,
            'content_type' => file.content_type,
            'temp_path' => temp_path.to_s,
            'size' => file.size
          }
        end
        
        if uploaded_files_data.any?
          # Enqueue the background job
          job = PhotoImportJob.perform_async(uploaded_files_data, current_user.id)
          
          flash[:notice] = "Photo import started! #{uploaded_files_data.length} file(s) are being processed in the background. You can monitor progress at /sidekiq"
        else
          flash[:error] = "No valid files selected for import."
        end
      else
        flash[:error] = "No files selected for import."
      end
      
      redirect_to family_photos_path
    else
      # Show the import form
      render 'import_photos'
    end
  end

  # Custom controller actions
  controller do
    def show
      @photo = Photo.find(params[:id])
      show! # This calls the default show action
    end
  end

end
