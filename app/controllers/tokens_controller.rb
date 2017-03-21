class TokensController < ApplicationController
  def show
    session[:user_id] = User.all.sample.id # ignore this, its just randomly
                                           # grabbing an User
    @user = User.find(session[:user_id])
    Token.find_by(user: @user).destroy if Token.find_by(user: @user) # cleanup old tokens
    @token = Token.create(user: @user)
    @room_token = SecureRandom.urlsafe_base64
  end

  def consume
    token_value = params[:token]
    room_token = params[:room_token]
    # room_guid = params[:room_guid]
    token = Token.find_by(value: token_value)

    # p ["token: #{token_value}", "room_guid: #{room_guid}"]

    if token # && room_guid
      # current_user = User.find(session[:user_id])
      user = token.user

      # ActionCable.server.broadcast channel: "token_logins", room: token_value,
      # ActionCable.server.broadcast "token_logins_#{token_value}",
      # ActionCable.server.broadcast "token_logins_CONSTANT_ROOM_NAME",
      ActionCable.server.broadcast "token_logins_#{room_token}",
        user_email: user.email,
        user_password_token: user.password_token
        # authentication: true,
        # token: token_value,
      head :ok
    else
      Token.find_by(value: token_value).destroy # invalidate Token value
      redirect_to "tokens#show"
    end
  end

  # Here we are calling the `#broadcast` method on our Action Cable server, and passing it arguments:
  # - 'token_logins', the name of the channel to which we are broadcasting.
  # - Some content that will be sent through the channel as JSON:
  #   - `authentication`, set to the content of the message we just created.
  #   - `user`, set to the username of the user who created the message.
end
