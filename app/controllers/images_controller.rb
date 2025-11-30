class ImagesController < ApplicationController
  before_action :authenticate_user!
  before_action :find_medium

  def show
    Rails.logger.info "=== IMAGES CONTROLLER DEBUG ==="
    Rails.logger.info "Medium ID: #{@medium.id}"
    Rails.logger.info "Medium current_filename: #{@medium.current_filename}"
    Rails.logger.info "Medium storage_state: #{@medium.aasm.current_state}"
    
    # For photos, serve the primary file if it exists, otherwise serve root file
    file_path = nil
    if @medium.medium_type == 'photo' && @medium.primary_file_exists?
      file_path = @medium.primary_file_path
      Rails.logger.info "Photo with primary version - serving: #{file_path}"
    else
      file_path = @medium.full_file_path
      Rails.logger.info "Serving root file: #{file_path}"
    end
    
    Rails.logger.info "File exists: #{File.exist?(file_path) if file_path}"
    
    if file_path && File.exist?(file_path)
      Rails.logger.info "✅ Serving file from: #{file_path}"
      send_data File.read(file_path), 
                type: @medium.content_type, 
                disposition: 'inline',
                filename: @medium.original_filename
    else
      Rails.logger.error "❌ File not found: #{file_path}"
      head :not_found
    end
    Rails.logger.info "=== END IMAGES CONTROLLER DEBUG ==="
  end

  def thumbnail
    if @medium.medium_type == 'photo' && @medium.mediable&.thumbnail_path && File.exist?(@medium.mediable.thumbnail_path)
      send_data File.read(@medium.mediable.thumbnail_path), 
                type: 'image/jpeg', 
                disposition: 'inline',
                filename: "thumb_#{@medium.original_filename}"
    else
      head :not_found
    end
  end

  private

  def find_medium
    @medium = Medium.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
