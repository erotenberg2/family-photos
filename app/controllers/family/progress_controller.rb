class Family::ProgressController < ApplicationController
  before_action :authenticate_user!

  def index
    # Get all active progress data for the current user
    progress_data = ProgressTrackerService.get_all_active_sessions(current_user.id)
    
    render json: {
      status: 'success',
      data: progress_data,
      timestamp: Time.current.iso8601
    }
  end

  def show_session
    session_id = params[:session_id]
    
    unless session_id.present?
      render json: { status: 'error', message: 'Session ID required' }, status: 400
      return
    end

    session_data = ProgressTrackerService.get_upload_session(session_id)
    
    if session_data && session_data['user_id'] == current_user.id
      render json: {
        status: 'success',
        data: session_data,
        timestamp: Time.current.iso8601
      }
    else
      render json: { status: 'error', message: 'Session not found or access denied' }, status: 404
    end
  end

  def batch
    batch_id = params[:batch_id]
    
    unless batch_id.present?
      render json: { status: 'error', message: 'Batch ID required' }, status: 400
      return
    end

    batch_data = ProgressTrackerService.get_post_processing_batch(batch_id)
    
    if batch_data
      render json: {
        status: 'success',
        data: batch_data,
        timestamp: Time.current.iso8601
      }
    else
      render json: { status: 'error', message: 'Batch not found' }, status: 404
    end
  end

  def cleanup
    # Only allow admins to trigger cleanup
    unless current_user.respond_to?(:admin?) && current_user.admin?
      render json: { status: 'error', message: 'Access denied' }, status: 403
      return
    end

    cleaned_count = ProgressTrackerService.cleanup_old_entries
    
    render json: {
      status: 'success',
      message: "Cleaned up #{cleaned_count} old progress entries",
      cleaned_count: cleaned_count
    }
  end
end
