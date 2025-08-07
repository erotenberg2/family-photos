class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  protected

  # Authentication method for AdminUser (backend admin access)
  # Note: Devise automatically provides authenticate_admin_user!, current_admin_user, etc.
  # We just need to ensure they're available

  # Override user_signed_in? to include active check
  def user_signed_in?
    super && current_user&.active?
  end

  # Helper method to check if current user has admin privileges
  def current_user_admin?
    current_user&.admin_level?
  end

  # Authorization helper for family features
  def authorize_active_user!
    redirect_to root_path, alert: 'Access denied.' unless current_user&.active?
  end

  # Authorization helper for admin features
  def authorize_admin_user!
    redirect_to root_path, alert: 'Admin access required.' unless current_user_admin?
  end

  # Store user for later redirect
  def store_user_location!
    store_location_for(:user, request.fullpath)
  end

  private

  # Warden helper (Devise dependency)
  def warden
    request.env['warden']
  end
end
