class SessionsController < ApplicationController
  # respond_to :js, :json, :html

  def create
    # user = User.find_by(email: params[:userData][:user_email], password_token: params[:userData][:user_password_token])
    user = User.find_by(email: params[:user_email], password_token: params[:user_password_token])
    p params

    if user
      session[:user_id] = user.id # login user
      Token.find_by(user: user).destroy if Token.find_by(user: user) # nullify token, so it cannot be reused
      respond_to do |format|
        format.json { render json: { success: true, url: user_url(user) } }
        format.html { redirect_to user }
      end
    else
      redirect_to root_path
    end
  end
end
