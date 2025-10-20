ActiveAdmin.register Medium, namespace: :family, as: 'Media' do

  # Add custom action buttons to index page
  action_item :import_media, only: :index do
    link_to 'Import Media', '#', 
            class: 'btn btn-primary', 
            onclick: 'openImportPopup(); return false;',
            'data-import-popup-url': import_media_popup_family_media_path
  end

  # Permitted parameters
  permit_params :file_path, :file_size, :original_filename, :content_type, :md5_hash,
                :datetime_user, :datetime_intrinsic, :datetime_inferred, :medium_type, :uploaded_by_id, :user_id

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
    
    column "Type", sortable: false do |medium|
      case medium.medium_type
      when 'photo'
        content_tag :div, "📸", style: "font-size: 20px; text-align: center;", title: "Photo"
      when 'video'
        content_tag :div, "🎬", style: "font-size: 20px; text-align: center;", title: "Video"
      when 'audio'
        content_tag :div, "🎵", style: "font-size: 20px; text-align: center;", title: "Audio"
      else
        content_tag :div, "📄", style: "font-size: 20px; text-align: center;", title: "Unknown"
      end
    end
    
    column "Processed", sortable: false do |medium|
      case medium.post_processing_status
      when 'completed'
        if medium.post_processed?
          content_tag :div, "✅", style: "font-size: 18px; text-align: center; color: #28a745;", title: "Processing completed successfully"
        else
          content_tag :div, "❌", style: "font-size: 18px; text-align: center; color: #dc3545;", title: "Processing failed"
        end
      when 'in_progress'
        content_tag :div, "⏳", style: "font-size: 18px; text-align: center; color: #ffc107;", title: "Processing in progress"
      when 'not_started'
        content_tag :div, "⏸️", style: "font-size: 18px; text-align: center; color: #6c757d;", title: "Processing queued"
      else
        content_tag :div, "❓", style: "font-size: 18px; text-align: center; color: #6c757d;", title: "Unknown status"
      end
    end
    
    column "Location", sortable: false do |medium|
      if medium.has_location?
        content_tag :div, "📍", style: "font-size: 16px; text-align: center;", title: "Location available"
      else
        content_tag :div, "", style: "font-size: 16px; text-align: center;"
      end
    end
    
    column :original_filename
    column :user
    column :uploaded_by
    column :effective_datetime do |medium|
      if medium.effective_datetime
        content_tag :div, medium.effective_datetime.strftime("%Y-%m-%d %H:%M"), 
                    title: "Source: #{medium.datetime_source}"
      else
        content_tag :div, "No date", style: "color: #999;"
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
  filter :datetime_user
  filter :datetime_intrinsic
  filter :datetime_inferred
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
      row :datetime_user do |medium|
        if medium.datetime_user
          content_tag :div, medium.datetime_user.strftime("%Y-%m-%d %H:%M:%S"), style: "color: #0066cc;"
        else
          content_tag :div, "Not set", style: "color: #999;"
        end
      end
      row :datetime_intrinsic do |medium|
        if medium.datetime_intrinsic
          content_tag :div, medium.datetime_intrinsic.strftime("%Y-%m-%d %H:%M:%S"), style: "color: #009900;"
        else
          content_tag :div, "No EXIF data", style: "color: #999;"
        end
      end
      row :datetime_inferred do |medium|
        if medium.datetime_inferred
          content_tag :div, medium.datetime_inferred.strftime("%Y-%m-%d %H:%M:%S"), style: "color: #ff6600;"
        else
          content_tag :div, "Not needed", style: "color: #999;"
        end
      end
      row :effective_datetime do |medium|
        if medium.effective_datetime
          content_tag :div, medium.effective_datetime.strftime("%Y-%m-%d %H:%M:%S"), style: "font-weight: bold;"
        else
          content_tag :div, "No date available", style: "color: #cc0000; font-weight: bold;"
        end
      end
      row :datetime_source_last_modified
      row :user
      row :uploaded_by
      row :md5_hash
      row :created_at
      row :updated_at
      row :processing_started_at
      row :processing_completed_at
      row "Processing Duration" do |resource|
        if resource.post_processing_duration
          "#{(resource.post_processing_duration * 1000).round}ms"
        else
          "—"
        end
      end
      row "Processing Status" do |resource|
        case resource.post_processing_status
        when 'completed'
          status_tag "Completed", class: :ok
        when 'in_progress'
          status_tag "In Progress", class: :warning
        when 'not_started'
          status_tag "Not Started", class: :no
        else
          status_tag "Unknown", class: :error
        end
      end
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

  # Collection action for importing media in popup
  collection_action :import_media_popup, method: [:get, :post] do
    if request.post?
      # Handle the media import (same logic as old import_media)
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
        
        # Get total files count from frontend
        total_files_selected = params[:total_files_selected]&.to_i || all_files.length
        
        if upload_log.nil?
          # First batch - create new upload log
          batch_id = SecureRandom.uuid
          upload_log = UploadLog.create!(
            user: current_user,
            batch_id: batch_id,
            session_id: session_id,
            session_started_at: Time.current,
            user_agent: request.user_agent,
            total_files_selected: total_files_selected, # Use total files from frontend
            files_imported: 0,
            files_skipped: 0,
            files_failed: 0,
            files_data: []
          )
          Rails.logger.info "Created new UploadLog for session: #{session_id} with #{total_files_selected} total files"
          
          # Start Redis progress tracking for the session with total files count
          ProgressTrackerService.start_upload_session(session_id, current_user.id, total_files_selected)
        else
          # Subsequent batch - use existing upload log
          batch_id = upload_log.batch_id
          Rails.logger.info "Using existing UploadLog for session: #{session_id}"
        end
        
        # Start Redis progress tracking for this batch
        ProgressTrackerService.start_upload_batch(session_id, batch_id, all_files.length)
        
        # Update total files selected for this batch (only for first batch)
        if upload_log.total_files_selected < total_files_selected
          upload_log.update!(total_files_selected: total_files_selected)
        end
        
        imported_count = 0
        skipped_count = 0
        failed_count = 0
        errors = []
        skipped_files = []
        failed_files = []
        
        # Get client file paths if provided
        client_file_paths = params[:client_file_paths] || []
        
        # Process rejected files first (unsupported file types = skipped)
        rejected_files = all_files - filtered_files.map { |f| f[:file] }
        rejected_files.each_with_index do |file, index|
          # Find the client file path for this rejected file
          rejected_file_index = all_files.index(file)
          client_file_path = client_file_paths[rejected_file_index] if rejected_file_index
          
          skipped_count += 1
          skipped_files << "#{file.original_filename}: File type not supported"
          
          upload_log.add_file_data(
            filename: file.original_filename,
            file_size: file.size,
            content_type: file.content_type,
            status: 'skipped',
            skip_reason: 'File type not supported for import',
            client_file_path: client_file_path
          )
          
          # Update Redis progress as skipped (not failed)
          ProgressTrackerService.update_upload_progress(session_id, batch_id, file.original_filename, 'skipped', 'File type not supported')
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
            
            # Update Redis progress
            ProgressTrackerService.update_upload_progress(session_id, batch_id, file.original_filename, 'uploaded')
                else
                  error_msg = result[:error] || "Unknown error"
                  
                  # Check if this is a duplicate file (skipped, not failed)
                  if error_msg.include?('duplicate') || error_msg.include?('already exists')
                    skipped_count += 1
                    skipped_files << "#{file.original_filename}: #{error_msg}"
                    Rails.logger.info "⏭️ Skipped duplicate: #{file.original_filename} - #{error_msg}"
                    
                    # Add skipped import to upload log
                    upload_log.add_file_data(
                      filename: file.original_filename,
                      file_size: file.size,
                      content_type: file.content_type,
                      status: 'skipped',
                      skip_reason: error_msg,
                      client_file_path: client_file_path
                    )
                    
                    # Update Redis progress as skipped
                    ProgressTrackerService.update_upload_progress(session_id, batch_id, file.original_filename, 'skipped', error_msg)
                  else
                    # This is a real failure
                    failed_count += 1
                    failed_files << "#{file.original_filename}: #{error_msg}"
                    errors << "#{file.original_filename}: #{error_msg}"
                    Rails.logger.error "❌ Failed to import: #{file.original_filename} - #{error_msg}"
                    
                    # Add failed import to upload log
                    upload_log.add_file_data(
                      filename: file.original_filename,
                      file_size: file.size,
                      content_type: file.content_type,
                      status: 'failed',
                      skip_reason: error_msg,
                      client_file_path: client_file_path
                    )
                    
                    # Update Redis progress as failed
                    ProgressTrackerService.update_upload_progress(session_id, batch_id, file.original_filename, 'failed', error_msg)
                  end
                end
        end
        
        # Update the upload session statistics
        upload_log.update!(
          files_imported: upload_log.files_imported + imported_count,
          files_skipped: upload_log.files_skipped + skipped_count,
          files_failed: upload_log.files_failed + failed_count
        )
        
        # Complete batch progress tracking
        ProgressTrackerService.complete_upload_batch(session_id, batch_id)
        
        # Enqueue asynchronous post-processing for this batch
        if imported_count > 0
          Rails.logger.info "🚀 Enqueuing batch post-processing job for batch: #{batch_id}, session: #{session_id}"
          BatchPostProcessJob.perform_later(batch_id, session_id)
        end
        
        # Check if this might be the final batch by looking at frontend parameters
        is_final_batch = params[:is_final_batch] == 'true'
        
        if is_final_batch
          # Mark session as completed
          upload_log.update!(
            session_completed_at: Time.current,
            completion_status: 'complete'
          )
          Rails.logger.info "Completed UploadLog session: #{session_id}"
          
          # Complete session progress tracking
          ProgressTrackerService.complete_upload_session(session_id)
        end
        
        Rails.logger.info "=== IMPORT SUMMARY ==="
        Rails.logger.info "Successfully imported: #{imported_count}"
        Rails.logger.info "Errors: #{errors.length}"
        
        render json: { 
          status: 'success', 
          imported_count: imported_count,
          skipped_count: skipped_count,
          failed_count: failed_count,
          total_count: all_files.length,
          error_count: errors.length,
          errors: errors,
          skipped_files: skipped_files,
          failed_files: failed_files
        }
      else
        Rails.logger.error "No media files found in request"
        render json: { 
          status: 'error', 
          message: "No files provided" 
        }, status: 400
      end
    else
      # Render popup layout
      render layout: false
    end
  end

end
