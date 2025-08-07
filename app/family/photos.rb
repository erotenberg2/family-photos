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
    # Photo preview panel
    panel "Photo Preview" do
      div style: "text-align: center; margin: 20px 0;" do
        if photo.thumbnail_path && File.exist?(photo.thumbnail_path)
          image_tag("data:image/#{photo.content_type.split('/').last};base64,#{Base64.encode64(File.read(photo.thumbnail_path))}", 
                    style: "max-width: 400px; max-height: 400px; object-fit: contain; border: 1px solid #ddd; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);",
                    alt: photo.title || photo.original_filename)
        elsif photo.file_path && File.exist?(photo.file_path)
          # Fallback to original image if thumbnail doesn't exist
          image_tag("data:image/#{photo.content_type.split('/').last};base64,#{Base64.encode64(File.read(photo.file_path))}", 
                    style: "max-width: 400px; max-height: 400px; object-fit: contain; border: 1px solid #ddd; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);",
                    alt: photo.title || photo.original_filename)
        else
          div "Image file not found", style: "padding: 40px; background: #f0f0f0; color: #666; border-radius: 8px;"
        end
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
      # Handle the photo import
      imported_count = 0
      errors = []
      
      if params[:photos].present?
        params[:photos].each do |photo_param|
          begin
            # Process each uploaded file
            file = photo_param[:file]
            next unless file.present?
            
            # Validate it's an image
            unless file.content_type.start_with?('image/')
              errors << "#{file.original_filename}: Not a valid image file"
              next
            end
            
            # Generate unique file path
            timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
            random_suffix = SecureRandom.hex(4)
            file_extension = File.extname(file.original_filename)
            stored_filename = "#{timestamp}_#{random_suffix}#{file_extension}"
            
            # Create upload directory if it doesn't exist
            upload_dir = Rails.root.join('storage', 'photos')
            FileUtils.mkdir_p(upload_dir) unless Dir.exist?(upload_dir)
            
            # Full file path
            file_path = upload_dir.join(stored_filename).to_s
            
            # Save file to disk
            File.open(file_path, 'wb') do |f|
              f.write(file.read)
            end
            
            # Calculate MD5 hash
            md5_hash = Digest::MD5.file(file_path).hexdigest
            
            # Check for duplicates
            existing_photo = Photo.find_by(md5_hash: md5_hash)
            if existing_photo
              File.delete(file_path) # Clean up duplicate file
              errors << "#{file.original_filename}: Duplicate photo already exists"
              next
            end
            
            # Extract image dimensions using MiniMagick
            require 'mini_magick'
            image = MiniMagick::Image.open(file_path)
            width = image.width
            height = image.height
            
            # Create Photo record
            photo = Photo.new(
              title: File.basename(file.original_filename, '.*').humanize,
              original_filename: file.original_filename,
              content_type: file.content_type,
              file_size: file.size,
              file_path: file_path,
              md5_hash: md5_hash,
              width: width,
              height: height,
              uploaded_by: current_user,
              user: current_user
            )
            
            if photo.save
              imported_count += 1
            else
              # Clean up file if photo creation failed
              File.delete(file_path) if File.exist?(file_path)
              errors << "#{file.original_filename}: #{photo.errors.full_messages.join(', ')}"
            end
            
          rescue => e
            # Clean up file if processing failed
            File.delete(file_path) if defined?(file_path) && File.exist?(file_path)
            errors << "#{file&.original_filename || 'Unknown file'}: #{e.message}"
          end
        end
      end
      
      if imported_count > 0
        flash[:notice] = "Successfully imported #{imported_count} photo(s)."
      end
      
      if errors.any?
        flash[:error] = "Errors encountered:\n#{errors.join("\n")}"
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
