class SessionsController < ApplicationController
  def create
    user = User.find_by(email: params[:user_email])
    internal_token = InternalToken.find_by(value: params[:user_password_token])
    #   Token.find_by(type: "InternalToken", value: params[:user_password_token])

    if internal_token.user == user
      session[:user_id] = user.id # login user

      # nullify token, so it cannot be reused
      internal_token.destroy

      # reset User internal application password (maybe)
      # user.update(password_token: SecureRandom.urlsafe_base64)

      respond_to do |format|
        format.json { render json: { success: true, url: welcome_url } }
        format.html { redirect_to welcome_url }
      end
    else
      redirect_to root_path
    end
  end

  def destroy
    session.delete(:user_id)
    session[:user_id] = nil
    @current_user = nil
    redirect_to root_path
  end
end
