class TokensController < ApplicationController
  def show
    # Ignore this, its just randomly, grabbing an User for their Token. You
    # would handle this in the mobile application the User is logged into
    session[:user_id] = User.all.sample.id
    @user = User.find(session[:user_id])
    @token = Token.create(user: @user)

    # keep this line
    @room_token = SecureRandom.urlsafe_base64
  end

  def consume
    room_token = params[:room_token]
    user_token = params[:user_token] # This will come from the Mobile App

    if user_token && room_token
      user = Token.find_by(value: user_token).user

      # The `user.password_token` is another random token that only the
      # application knows about and will be re-submitted back to the application
      # to confirm the login for that user in the open room session
      ActionCable.server.broadcast("token_logins_#{room_token}",
                                   user_email: user.email,
                                   user_password_token: user.password_token)
      head :ok
    else
      redirect_to "tokens#show"
    end
  end
end

  # Here we are calling the `#broadcast` method on our Action Cable server, and passing it arguments:
  # - 'token_logins', the name of the channel to which we are broadcasting.
  # - Some content that will be sent through the channel as JSON:
  #   - `authentication`, set to the content of the message we just created.
  #   - `user`, set to the username of the user who created the message.
