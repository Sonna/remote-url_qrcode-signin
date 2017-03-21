<!--
- [ruby on rails - How can I implement Whatsapp life QR code authentication - Stack Overflow]
  (http://stackoverflow.com/questions/42879668/how-can-i-implement-whatsapp-life-qr-code-authentication/42881593#42881593)
-->

_I am adding a new answer for two reasons:_

_1. Acacia repharse the question with an emphasis on What's App redirection of
    the page with the QR Code being view, which I did not address in my initial
    solution due a misunderstanding of the problem, and_

_2. Some people have found the first answer helpful and this new answer would
    change it significantly that whilst similar, but no longer the same_

> When the QR is scanned am able to reload the page where it was displayed and
> then redirect to another page
>
> -- Acacia

In order to achieve this there requires to some kind of open connection on the
page that is displaying the QRCode that something interpretting said QRCode can
use to effect it. However, because of the application you trying to mimic
requires that only that one User viewing the page is effected, whilst not
actually being logged in yet, would require something in the page to be unique.

For the solution to this problem you will need a couple of things:

1. An unique token to identify the not logged-in User can use to be contacted /
   influenced by an external browser

2. A way of logging in using JavaScript, in order to update the viewed page to
   be logged after previous step's event

3. Some kind of authentication Token that can be exchange between the
   application and the external QRCode scanner application, in order to
   authentication themselves as a specific User

_The following solution stubs out the above 3rd step since this is to
demonstrate the idea and is primarily focused on the server-side of the
application. That being said, the solution to the 3rd step should be as simple
as passing the know User authentication token by appending it to the URL within
the QRCode as an additional paramater (and submitting it as a POST request,
rather than as a GET request in this demonstration)._

You will need some random Tokens to use to authentication the User with and
exchange via URL embedded within the QCcode; e.g.

    $ rails generate model Token type:string value:string user:belongs_to

_`type` is a reserverd keyword within Rails, used for Single Table Inheritance.
It will be used to specific different kinds of / specialized Tokens within this
application._

To generate unique Token value that can be used within an URL and encode it
into a QRCode, use something like the following model(s) and code:

    # Gemfile
    gem "rqrcode" # QRCode generation

    # app/models/token.rb
    require "securerandom" # used for random token value generation

    class Token < ApplicationRecord
      before_create :generate_token_value

      belongs_to :user

      def generate_token_value
        begin
          self.value = SecureRandom.urlsafe_base64 #=> "b4GOKm4pOYU_-BOXcrUGDg"
        end while self.class.exists?(value: value)
      end

      def qr_code(room_id)
        RQRCode::QRCode.new(consume_url(room_id))
      end

      def consume_url(room_id)
        Rails.application.routes.url_helpers.url_for(
          host: "localhost:3000",
          controller: "tokens",
          action: "consume",
          user_token: value,
          room_id: room_id
        )
      end
    end

    # app/models/external_token.rb
    class ExternalToken < Token; end

    # app/models/internal_token.rb
    class InternalToken < Token; end

- `InternalTokens` will be only used within the application itself, and are
   short-lived

- `ExternalTokens` will be only used to interact with the application from
   outside; like your purposed mobile QRCode scanner application; where the User
   has either previously registered themselves or has logged in to allow for
   this authentication token to be generated and stored within the external app

Then display this QRCode somewhere in your application

    # e.g. app/views/tokens/show.html.erb
    <%= @external_token.qr_code(@room_id).as_html.html_safe %>

Then wire up your application's routes and controllers to process that generated
and encoded QRCode URL

    # config/routes.rb
    Rails.application.routes.draw do
      # ...
      get "/login", to: "sessions#new"
    end

    # app/controller/sessions_controller.rb
    class SessionsController < ApplicationController
      def create
        user = User.find_by(email: params[:email], token: params[:token])
        if user
          session[:user_id] = user.id # login user
          user.update(token: nil) # nullify token, so it cannot be reused
          redirect_to user
        else
          redirect_to root_path
        end
      end
    end



The only this solution does not address is the rolling room token generation,
which would either require either a JavaScript library to generate/regenerate
the URL with the Room Token or a Controller Action that return a regenerated
QRCode as either image or HTML that can be immediately displayed within the
page. Either method still requires you to have some JavaScript that closes the
current connection and opens a new one with a new room/session token that can
used so that only it can receive mesages from, after a certain amount of time.

**References:**

- [whomwah/rqrcode: A Ruby library that encodes QR Codes](https://github.com/whomwah/rqrcode)
- [Module: SecureRandom (Ruby 2_2_1)](https://ruby-doc.org/stdlib-2.2.1/libdoc/securerandom/rdoc/SecureRandom.html#method-c-urlsafe_base64)
- [#352 Securing an API - RailsCasts](http://railscasts.com/episodes/352-securing-an-api?view=asciicast)
