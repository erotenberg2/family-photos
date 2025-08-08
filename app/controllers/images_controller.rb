class ImagesController < ApplicationController
  before_action :authenticate_user!
  before_action :find_photo

  def show
    if @photo.file_path && File.exist?(@photo.file_path)
      send_data File.read(@photo.file_path), 
                type: @photo.content_type, 
                disposition: 'inline',
                filename: @photo.original_filename
    else
      head :not_found
    end
  end

  def thumbnail
    if @photo.thumbnail_path && File.exist?(@photo.thumbnail_path)
      send_data File.read(@photo.thumbnail_path), 
                type: 'image/jpeg', 
                disposition: 'inline',
                filename: "thumb_#{@photo.original_filename}"
    else
      head :not_found
    end
  end

  private

  def find_photo
    @photo = Photo.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
