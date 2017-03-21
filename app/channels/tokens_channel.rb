# app/channels/tokens_channel.rb

# Subscirbe to `"tokens"` channel

class TokensChannel < ApplicationCable::Channel
  def subscribed
    stream_from "token_logins_#{params[:room]}"
    # stream_from "token_logins_CONSTANT_ROOM_NAME"
  end
end
