class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  def current_user
    @current_user ||= User.find(session[:user_id])
  end

  def logout
    session.delete(:user_id)
    session[:user_id] = nil
    @current_user = nil
  end
end
