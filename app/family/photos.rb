ActiveAdmin.register Photo, namespace: :family do


  # Add custom action button to index page  
  action_item :import_photos, only: :index do
    link_to 'Import Photos', '#', class: 'btn btn-primary', onclick: 'openImportPopup(); return false;'
  end

  # Permitted parameters
  permit_params :title, :description, :file_path, :file_size, :width, :height, 
                :taken_at, :exif_data, :thumbnail_path, :thumbnail_width, 
                :thumbnail_height, :uploaded_by_id, :user_id, :original_filename, 
                :content_type, :md5_hash, :latitude, :longitude, :camera_make, :camera_model

  # Index page configuration
  index do
    # Include the family import JavaScript
    content_for :head do
      javascript_include_tag 'family_import'
    end

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
                    # Handle photo import with actual file uploads
       if params[:photos].present?
         Rails.logger.info "=== PHOTO IMPORT DEBUG ==="
         Rails.logger.info "Request content type: #{request.content_type}"
         Rails.logger.info "Photos params count: #{params[:photos].length}"
         Rails.logger.info "User ID: #{current_user.id}"
         
         # Create a unique temporary directory for this import session
         session_id = SecureRandom.hex(16)
         temp_dir = Rails.root.join('tmp', 'photo_uploads', session_id)
         FileUtils.mkdir_p(temp_dir)
         
         Rails.logger.info "Created temp directory: #{temp_dir}"
         
         file_count = 0
         
         params[:photos].each do |photo_param|
           file = photo_param[:file]
           next unless file.present?
           
           Rails.logger.info "Processing file: #{file.original_filename} (#{file.size} bytes)"
           
           # Save to temporary file with original structure
           original_filename = file.original_filename
           file_path = temp_dir.join(original_filename)
           
           # Create directory structure if needed
           FileUtils.mkdir_p(File.dirname(file_path))
           
           # Write file to temporary location
           File.open(file_path, 'wb') do |f|
             f.write(file.read)
           end
           
           file_count += 1
         end
         
         Rails.logger.info "Saved #{file_count} files to temp directory"
         
                 if file_count > 0
          # Process files directly (no background jobs)
          imported_count = 0
          errors = []
          
          params[:photos].each do |photo_param|
            file = photo_param[:file]
            next unless file.present?
            
            Rails.logger.info "=== PROCESSING FILE ==="
            Rails.logger.info "File: #{file.original_filename}"
            Rails.logger.info "Content type: #{file.content_type}"
            Rails.logger.info "File size: #{file.size} bytes"
            Rails.logger.info "File present: #{file.present?}"
            
            begin
              # Validate it's an image file
              unless file.content_type.start_with?('image/')
                Rails.logger.error "Not a valid image file: #{file.content_type}"
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
              
              # Write file to permanent location
              Rails.logger.info "Writing file to: #{file_path}"
              Rails.logger.info "Original file size: #{file.size} bytes"
              Rails.logger.info "File class: #{file.class}"
              Rails.logger.info "File tempfile: #{file.tempfile.path if file.respond_to?(:tempfile)}"
              
              # Copy from the tempfile directly
              if file.respond_to?(:tempfile) && file.tempfile
                FileUtils.copy_file(file.tempfile.path, file_path)
              else
                # Fallback: read and write the content
                File.open(file_path, 'wb') do |f|
                  f.write(file.read)
                end
              end
              
              Rails.logger.info "File written successfully, size: #{File.size(file_path)} bytes"
              
              # Calculate MD5 hash
              Rails.logger.info "Calculating MD5 hash..."
              md5_hash = Digest::MD5.file(file_path).hexdigest
              Rails.logger.info "MD5 hash: #{md5_hash}"
              
              # Check for duplicates
              existing_photo = Photo.find_by(md5_hash: md5_hash)
              if existing_photo
                Rails.logger.info "Duplicate found, cleaning up file"
                File.delete(file_path) # Clean up duplicate file
                errors << "#{file.original_filename}: Duplicate photo already exists"
                next
              end
              Rails.logger.info "No duplicate found, proceeding with import"
              
              # Extract image dimensions using MiniMagick
              require 'mini_magick'
              begin
                image = MiniMagick::Image.open(file_path)
                width = image.width
                height = image.height
              rescue => e
                Rails.logger.error "Failed to read image dimensions for #{file.original_filename}: #{e.message}"
                # Try to get dimensions using identify command directly
                begin
                  result = `identify -format "%w %h" "#{file_path}" 2>/dev/null`
                  if result && result.strip.match(/^\d+ \d+$/)
                    width, height = result.strip.split(' ').map(&:to_i)
                  else
                    raise "Could not determine image dimensions"
                  end
                rescue => identify_error
                  Rails.logger.error "Identify command also failed for #{file.original_filename}: #{identify_error.message}"
                  errors << "#{file.original_filename}: Cannot read image dimensions - file may be corrupted or unsupported"
                  File.delete(file_path) # Clean up the file
                  next
                end
              end
              
              # Create Photo record
              Rails.logger.info "Creating Photo record..."
              Rails.logger.info "  - title: #{File.basename(file.original_filename, '.*').humanize}"
              Rails.logger.info "  - file_path: #{file_path}"
              Rails.logger.info "  - original_filename: #{file.original_filename}"
              Rails.logger.info "  - content_type: #{file.content_type}"
              Rails.logger.info "  - file_size: #{File.size(file_path)}"
              Rails.logger.info "  - width: #{width}, height: #{height}"
              Rails.logger.info "  - md5_hash: #{md5_hash}"
              Rails.logger.info "  - user_id: #{current_user.id}"
              
              photo = Photo.new(
                title: File.basename(file.original_filename, '.*').humanize,
                file_path: file_path,
                original_filename: file.original_filename,
                content_type: file.content_type,
                file_size: File.size(file_path),
                width: width,
                height: height,
                md5_hash: md5_hash,
                user: current_user,
                uploaded_by: current_user
              )
              
              if photo.save
                imported_count += 1
                Rails.logger.info "✅ Successfully imported: #{file.original_filename} (ID: #{photo.id})"
              else
                Rails.logger.error "❌ Failed to create Photo record:"
                Rails.logger.error "  - Errors: #{photo.errors.full_messages}"
                Rails.logger.error "  - Valid: #{photo.valid?}"
                errors << "#{file.original_filename}: Photo creation failed: #{photo.errors.full_messages.join(', ')}"
              end
              
            rescue => e
              Rails.logger.error "❌ Exception during import of #{file.original_filename}:"
              Rails.logger.error "  - Error: #{e.message}"
              Rails.logger.error "  - Backtrace: #{e.backtrace.first(5).join("\n    ")}"
              errors << "#{file.original_filename}: #{e.message}"
            end
          end
          
          # Clean up temp directory
          FileUtils.rm_rf(temp_dir)
          
          Rails.logger.info "=== UPLOAD SUMMARY ==="
          Rails.logger.info "Total files processed: #{params[:photos].length}"
          Rails.logger.info "Successfully imported: #{imported_count}"
          Rails.logger.info "Errors: #{errors.length}"
          if errors.any?
            Rails.logger.error "Error details:"
            errors.each { |error| Rails.logger.error "  - #{error}" }
          end
          
          render json: { 
            status: 'success', 
            message: "Imported #{imported_count} photos#{errors.any? ? " (#{errors.length} failed)" : ""}",
            imported_count: imported_count,
            error_count: errors.length
          }
         else
           Rails.logger.error "No valid files found in upload"
           render json: { 
             status: 'error', 
             message: "No valid files selected for import" 
           }, status: 400
         end
       else
         Rails.logger.error "No photos params found in request"
         render json: { 
           status: 'error', 
           message: "No files provided" 
         }, status: 400
       end
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
