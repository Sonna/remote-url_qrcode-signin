# app/channels/tokens_channel.rb

# Subscribe to `"tokens"` channel

class TokensChannel < ApplicationCable::Channel
  def subscribed
    stream_from "token_logins_#{params[:room]}"
  end
end
