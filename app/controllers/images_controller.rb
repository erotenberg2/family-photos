class ImagesController < ApplicationController
  before_action :authenticate_user!
  before_action :find_medium

  def show
    if @medium.file_path && File.exist?(@medium.file_path)
      send_data File.read(@medium.file_path), 
                type: @medium.content_type, 
                disposition: 'inline',
                filename: @medium.original_filename
    else
      head :not_found
    end
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
