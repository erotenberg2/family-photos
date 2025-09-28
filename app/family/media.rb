ActiveAdmin.register Medium, namespace: :family, as: 'Media' do

  # Add custom action buttons to index page
  action_item :import_media, only: :index do
    link_to 'Import Media', import_media_family_media_path, class: 'btn btn-primary'
  end

  # Permitted parameters
  permit_params :file_path, :file_size, :original_filename, :content_type, :md5_hash,
                :width, :height, :taken_at, :medium_type, :uploaded_by_id, :user_id

  # Index page configuration
  index do
    selectable_column
    
    column "Thumbnail", sortable: false do |medium|
      link_to family_medium_path(medium) do
        case medium.medium_type
        when 'photo'
          if medium.mediable&.thumbnail_path && File.exist?(medium.mediable.thumbnail_path)
            # Use small thumbnail (128x128 max)
            image_tag("data:image/jpg;base64,#{Base64.encode64(File.read(medium.mediable.thumbnail_path))}", 
                      style: "max-width: 60px; max-height: 60px; object-fit: cover; border-radius: 4px; cursor: pointer; transition: transform 0.2s ease; display: block;",
                      alt: medium.mediable&.title || medium.original_filename,
                      onmouseover: "this.style.transform='scale(1.05)'",
                      onmouseout: "this.style.transform='scale(1)'")
          else
            # Show placeholder for unprocessed photos (don't load full image)
            content_tag :div, "📷", style: "width: 60px; height: 60px; background: #f8f9fa; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px; cursor: pointer; border: 2px dashed #dee2e6;"
          end
        when 'audio'
          content_tag :div, "🎵", style: "width: 60px; height: 60px; background: #f0f0f0; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px; cursor: pointer;"
        when 'video'
          content_tag :div, "🎬", style: "width: 60px; height: 60px; background: #f0f0f0; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px; cursor: pointer;"
        else
          content_tag :div, "📄", style: "width: 60px; height: 60px; background: #f0f0f0; display: flex; align-items: center; justify-content: center; font-size: 24px; border-radius: 4px; cursor: pointer;"
        end
      end
    end
    
    column "Type" do |medium|
      status_tag medium.medium_type.humanize, class: "#{medium.medium_type}_type"
    end
    
    column "Processing Status", sortable: false do |medium|
      if medium.post_processed?
        status_tag "Processed", class: :ok
      else
        status_tag "Pending", class: :warning
      end
    end
    
    column "Title" do |medium|
      medium.mediable&.title || "Untitled"
    end
    
    column :original_filename
    column :user
    column :uploaded_by
    column :taken_at
    column "Dimensions" do |medium|
      if medium.width && medium.height
        "#{medium.width}×#{medium.height}"
      else
        "—"
      end
    end
    column "File Size" do |medium|
      medium.file_size_human
    end
    column :content_type
    column :created_at
    
    actions
  end

  # Filters
  filter :medium_type, as: :select, collection: Medium.medium_types.keys.map { |k| [k.humanize, k] }
  filter :content_type, as: :select, collection: proc { Medium.distinct.pluck(:content_type).compact.sort }
  filter :original_filename
  filter :user
  filter :uploaded_by
  filter :taken_at
  filter :created_at

  # Show page configuration
  show do
    # Add CSS for hover effects
    content_for :head do
      raw <<~CSS
        <style>
          .media-preview-link:hover img, .media-preview-link:hover video {
            box-shadow: 0 4px 12px rgba(0,0,0,0.2) !important;
            transform: scale(1.02);
          }
          .media-preview-link img, .media-preview-link video {
            transition: all 0.3s ease !important;
          }
        </style>
      CSS
    end

    # Media preview panel
    panel "Media Preview" do
      case resource.medium_type
      when 'photo'
        if resource.mediable&.preview_path && File.exist?(resource.mediable.preview_path)
          link_to image_tag("data:image/jpg;base64,#{Base64.encode64(File.read(resource.mediable.preview_path))}", 
                    style: "max-width: 400px; max-height: 400px; object-fit: contain; border: 1px solid #ddd; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); display: block; margin: 0 auto;",
                    alt: resource.mediable&.title || resource.original_filename), image_path(resource), target: "_blank"
        else
          div "Photo preview not available", style: "padding: 40px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
        end
      when 'audio'
        if resource.file_exists?
          audio_tag image_path(resource), controls: true, style: "width: 100%; max-width: 400px; margin: 0 auto; display: block;"
        else
          div "Audio file not found", style: "padding: 40px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
        end
      when 'video' 
        if resource.file_exists?
          video_tag image_path(resource), controls: true, style: "max-width: 400px; max-height: 400px; margin: 0 auto; display: block;"
        else
          div "Video file not found", style: "padding: 40px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
        end
      else
        div "Preview not available for this media type", style: "padding: 40px; background: #f0f0f0; color: #666; border-radius: 8px; text-align: center;"
      end
    end

    attributes_table do
      row :id
      row "Type" do |resource|
        status_tag resource.medium_type.humanize, class: "#{resource.medium_type}_type"
      end
      row "Title" do |resource|
        resource.mediable&.title || "Untitled"
      end
      row "Description" do |resource|
        resource.mediable&.description || "No description"
      end
      row :original_filename
      row :file_path
      row :content_type
      row :file_size do |resource|
        resource.file_size_human
      end
      row :dimensions do |resource|
        if resource.width && resource.height
          "#{resource.width} × #{resource.height} pixels"
        else
          "Not available"
        end
      end
      row :taken_at
      row :user
      row :uploaded_by
      row :md5_hash
      row :created_at
      row :updated_at
    end

    # Show type-specific details
    if resource.mediable
      case resource.medium_type
      when 'photo'
        panel "Photo Details" do
          attributes_table_for resource.mediable do
            row :camera_make
            row :camera_model
            row :location do |photo|
              if photo.latitude && photo.longitude
                "#{photo.latitude}, #{photo.longitude}"
              else
                "No location data"
              end
            end
            row :thumbnail_dimensions do |photo|
              if photo.thumbnail_width && photo.thumbnail_height
                "#{photo.thumbnail_width} × #{photo.thumbnail_height} pixels (#{Photo::THUMBNAIL_MAX_SIZE}px max)"
              else
                "Not generated"
              end
            end
            row :preview_dimensions do |photo|
              if photo.preview_width && photo.preview_height
                "#{photo.preview_width} × #{photo.preview_height} pixels (#{Photo::PREVIEW_MAX_SIZE}px max)"
              else
                "Not generated"
              end
            end
          end

          if resource.mediable.exif_data.present?
            h4 "EXIF Data"
            pre JsonFormatterService.pretty_format(resource.mediable.exif_data), 
                style: "background: #f8f8f8; padding: 15px; border-radius: 5px; overflow-x: auto; font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace; font-size: 12px; line-height: 1.4; border: 1px solid #e0e0e0; white-space: pre-wrap;"
          end
        end
      end
    end
  end

  # Collection action for importing media
  collection_action :import_media, method: [:get, :post] do
    if request.post?
      # Handle the media import
      allowed_types = params[:media_types] || ['all']
      
      if params[:media_files].present?
        Rails.logger.info "=== MEDIA IMPORT DEBUG ==="
        Rails.logger.info "Allowed types: #{allowed_types}"
        Rails.logger.info "Files count: #{params[:media_files].length}"
        Rails.logger.info "User ID: #{current_user.id}"
        
        # Filter files by allowed types
        all_files = params[:media_files] || []
        filtered_files = Medium.filter_acceptable_files(all_files, allowed_types)
        
        Rails.logger.info "Total files: #{all_files.length}, Filtered files count: #{filtered_files.length}"
        
        # Generate session ID for this upload session
        session_id = session.id.to_s
        
        # Get or create upload log for this session
        upload_log = UploadLog.find_by(session_id: session_id, session_completed_at: nil)
        
        if upload_log.nil?
          # First batch - create new upload log
          batch_id = SecureRandom.uuid
          upload_log = UploadLog.create!(
            user: current_user,
            batch_id: batch_id,
            session_id: session_id,
            session_started_at: Time.current,
            user_agent: request.user_agent,
            total_files_selected: 0, # Will be incremented with each batch
            files_imported: 0,
            files_skipped: 0,
            files_data: []
          )
          Rails.logger.info "Created new UploadLog for session: #{session_id}"
        else
          # Subsequent batch - use existing upload log
          batch_id = upload_log.batch_id
          Rails.logger.info "Using existing UploadLog for session: #{session_id}"
        end
        
        # Update total files selected for this batch
        upload_log.update!(
          total_files_selected: upload_log.total_files_selected + all_files.length
        )
        
        imported_count = 0
        errors = []
        
        # Get client file paths if provided
        client_file_paths = params[:client_file_paths] || []
        
        # Process rejected files first
        rejected_files = all_files - filtered_files.map { |f| f[:file] }
        rejected_files.each_with_index do |file, index|
          # Find the client file path for this rejected file
          rejected_file_index = all_files.index(file)
          client_file_path = client_file_paths[rejected_file_index] if rejected_file_index
          
          upload_log.add_file_data(
            filename: file.original_filename,
            file_size: file.size,
            content_type: file.content_type,
            status: 'skipped',
            skip_reason: 'File type not supported for import',
            client_file_path: client_file_path
          )
        end
        
        # Process accepted files
        
        filtered_files.each_with_index do |file_info, index|
          file = file_info[:file]
          medium_type = file_info[:medium_type]
          # Find the client file path for this filtered file
          filtered_file_index = all_files.index(file)
          client_file_path = client_file_paths[filtered_file_index] if filtered_file_index
          
          Rails.logger.info "Processing #{medium_type}: #{file.original_filename} (client path: #{client_file_path})"
          
          # Disable post-processing to time upload phase separately
          result = Medium.create_from_uploaded_file(file, current_user, medium_type, post_process: false, batch_id: batch_id, session_id: session_id, client_file_path: client_file_path)
          
          if result[:success]
            imported_count += 1
            Rails.logger.info "✅ Successfully imported: #{file.original_filename}"
            
            # Add successful import to upload log
            upload_log.add_file_data(
              filename: file.original_filename,
              file_size: file.size,
              content_type: file.content_type,
              status: 'imported',
              client_file_path: client_file_path,
              medium: result[:medium]
            )
          else
            error_msg = result[:error] || "Unknown error"
            errors << "#{file.original_filename}: #{error_msg}"
            Rails.logger.error "❌ Failed to import: #{file.original_filename} - #{error_msg}"
            
            # Add failed import to upload log
            upload_log.add_file_data(
              filename: file.original_filename,
              file_size: file.size,
              content_type: file.content_type,
              status: 'skipped',
              skip_reason: error_msg,
              client_file_path: client_file_path
            )
          end
        end
        
        # Update the upload session statistics
        upload_log.update!(
          files_imported: upload_log.files_imported + imported_count,
          files_skipped: upload_log.files_skipped + (all_files.length - imported_count)
        )
        
        # Check if this might be the final batch by looking at frontend parameters
        is_final_batch = params[:is_final_batch] == 'true'
        
        if is_final_batch
          # Mark session as completed
          upload_log.update!(
            session_completed_at: Time.current,
            completion_status: 'complete'
          )
          Rails.logger.info "Completed UploadLog session: #{session_id}"
        end
        
        Rails.logger.info "=== IMPORT SUMMARY ==="
        Rails.logger.info "Successfully imported: #{imported_count}"
        Rails.logger.info "Errors: #{errors.length}"
        
        render json: { 
          status: 'success', 
          message: "Imported #{imported_count} media file(s)#{errors.any? ? " (#{errors.length} failed)" : ""}",
          imported_count: imported_count,
          error_count: errors.length,
          errors: errors
        }
      else
        Rails.logger.error "No media files found in request"
        render json: { 
          status: 'error', 
          message: "No files provided" 
        }, status: 400
      end
    else
      # Show the import form
      render 'import_media'
    end
  end

end
