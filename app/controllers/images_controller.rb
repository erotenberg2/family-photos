class ImagesController < ApplicationController
  before_action :authenticate_user!
  before_action :find_medium

  def show
    Rails.logger.info "=== IMAGES CONTROLLER DEBUG ==="
    Rails.logger.info "Medium ID: #{@medium.id}"
    Rails.logger.info "Medium file_path: #{@medium.file_path}"
    Rails.logger.info "Medium current_filename: #{@medium.current_filename}"
    Rails.logger.info "Medium full_file_path: #{@medium.full_file_path}"
    Rails.logger.info "Medium storage_state: #{@medium.aasm.current_state}"
    Rails.logger.info "File exists: #{File.exist?(@medium.full_file_path) if @medium.full_file_path}"
    
    if @medium.full_file_path && File.exist?(@medium.full_file_path)
      Rails.logger.info "✅ Serving file from: #{@medium.full_file_path}"
      send_data File.read(@medium.full_file_path), 
                type: @medium.content_type, 
                disposition: 'inline',
                filename: @medium.original_filename
    else
      Rails.logger.error "❌ File not found: #{@medium.full_file_path}"
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
