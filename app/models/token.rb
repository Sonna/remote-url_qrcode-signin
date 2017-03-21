require "securerandom"

class Token < ApplicationRecord
  before_create :generate_token_value

  belongs_to :user

  def generate_token_value
    begin
      self.value = SecureRandom.urlsafe_base64 #=> "b4GOKm4pOYU_-BOXcrUGDg"
    end while self.class.exists?(value: value)
  end

  def qr_code
    RQRCode::QRCode.new(
      Rails.application.routes.url_helpers.url_for(
        host: "localhost:3000",
        controller: "tokens",
        action: "consume",
        # email: email,
        token: value
      )
    )
  end
end
