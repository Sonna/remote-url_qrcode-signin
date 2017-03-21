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

I also hide the current `@room_id` within the `<head>` tags of the application
using the following:

    # e.g. app/views/tokens/show.html.erb
    <%= content_for :head, @room_id.html_safe %>

    # app/views/layouts/application.html.erb
    <!DOCTYPE html>
    <html>
      <head>
        <title>QrcodeApp</title>
        <!-- ... -->

        <%= tag("meta", name: "room-id", content: content_for(:head))  %>
        <!-- ... -->
      </head>

      <body>
        <%= yield %>
      </body>
    </html>

Then wire up your application's routes and controllers to process that generated
and encoded QRCode URL.

For Routes we need:

1. Route to present the QRCode tokens; `"token#show"`
2. Route to consume / process the QRCode tokens; `"token#consume"`
3. Route to log the User in with, over AJAX; `"sessions@create"`

We will also need some way of opening a connection within the display Token page
that can be interacted with to force it to login, for that we will need:

    mount ActionCable.server => "/cable"

_This will require Rails 5 and ActionCable to implment, otherwise another
Pub/Sub solution; like Faye; will need to be used instead with older versions._

All together the routes look kind of like this:

    # config/routes.rb
    Rails.application.routes.draw do
      # ...

      # Serve websocket cable requests in-process
      mount ActionCable.server => "/cable"

      get "/token-login", to: "tokens#consume"
      post "/login", to: "sessions#create"
      get "/logout", to: "sessions#destroy"
      get "welcome", to: "welcome#show"

      root "tokens#show"
    end

Then Controllers for those actions are as follows:

    # app/controller/tokens_controller.rb
    class TokensController < ApplicationController
      def show
        # Ignore this, its just randomly, grabbing an User for their Token. You
        # would handle this in the mobile application the User is logged into
        session[:user_id] = User.all.sample.id
        @user = User.find(session[:user_id])
        # @user_token = Token.create(type: "ExternalToken", user: @user)
        @user_token = ExternalToken.create(user: @user)

        # keep this line
        @room_id = SecureRandom.urlsafe_base64
      end

      def consume
        room_id = params[:room_id]
        user_token = params[:user_token] # This will come from the Mobile App

        if user_token && room_id
          # user = Token.find_by(type: "ExternalToken", value: user_token).user
          # password_token = Token.create(type: "InternalToken", user_id: user.id)
          user = ExternalToken.find_by(value: user_token).user
          password_token = InternalToken.create(user: user)

          # The `user.password_token` is another random token that only the
          # application knows about and will be re-submitted back to the application
          # to confirm the login for that user in the open room session
          ActionCable.server.broadcast("token_logins_#{room_id}",
                                       user_email: user.email,
                                       user_password_token: password_token.value)
          head :ok
        else
          redirect_to "tokens#show"
        end
      end
    end

The Tokens Controller `show` action primarily generates the `@room_id` value for
reuse in the view templates. The rest of the code in the `show` is just used to
demonstrate this kind of application.

The Tokens Controller `consume` action requires a `room_id` and `user_token` to
proceed, otherwise redirects the User back to QRCode sign in page. When they are
provided it then generates an `InternalToken` that is associated with the User
of the `ExternalToken` that it will then use to push a notification / event to
all rooms with said `room_id` (where there is only one that is unique to the
User viewing the QRCode page that generate this URL) whilst providing the
necessary authentication information for a User (or in this case our
application) to log into the application without a _password_, by quickly
generating an `InternalToken` to use instead.

_You could also pass in the User e-mail as param if the external application
knows about it, rather than assuming its correct in this demonstration example._

For the Sessions Controller, as follows:

    # app/controller/sessions_controller.rb
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

This Sessions Controller takes in the `user_email` and `user_password_token` to
make sure that these two match the same User internally before proceeding to
login. Then creates the user session with `session[:user_id]` and destroys the
`internal_token`, since it was a one time use only and is only used internally
within the application for this kind of authentication.

As well as, some kind of Welcome Controller for the Sessions `create` action to
redirect to after logging in

    # app/controller/welcome_controller.rb
    class WelcomeController < ApplicationController
      def show
        @user = current_user
        redirect_to root_path unless current_user
      end

      private

      def current_user
        @current_user ||= User.find(session[:user_id])
      end
    end

Since this aplication uses
[ActionCable](http://edgeguides.rubyonrails.org/action_cable_overview.html), we
have already mounted the `/cable` path, now we need to setup a Channel that is
unique to a given User. However, since the User is not logged in yet, we use the
`room_id` value that was previously generated by the Tokens Controller `show`
action since its random and unique.

    # app/channels/tokens_channel.rb

    # Subscribe to `"tokens"` channel
    class TokensChannel < ApplicationCable::Channel
      def subscribed
        stream_from "token_logins_#{params[:room_id]}" if params[:room_id]
      end
    end

That `room_id` was also embedded within the `<head>` (although it could a hidden
`<div>` element or the `id` attribtue of the QRCode, its up to you), which means
it can be pulled out to use in our JavaScript for receiving incoming boardcasts
to that room/QRCode; e.g.

    // app/assets/javascripts/channels/tokens.js

    var el = document.querySelectorAll('meta[name="room-id"]')[0];
    var roomID = el.getAttribute('content');

    App.tokens = App.cable.subscriptions.create(
      { channel: 'TokensChannel', room_id: roomID }, {

      received: function(data) {
        this.loginUser(data);
      },

      loginUser: function(data) {
        var userEmail = data.user_email;
        var userPasswordToken = data.user_password_token; // Mobile App's User token
        var userData = {
          user_email: userEmail,
          user_password_token: userPasswordToken
        };

        // `csrf_meta_tags` value
        var el = document.querySelectorAll('meta[name="csrf-token"]')[0];
        var csrfToken = el.getAttribute('content');

        var xmlhttp = new XMLHttpRequest();

        // Handle POST response on `onreadystatechange` callback
        xmlhttp.onreadystatechange = function() {
          if (xmlhttp.readyState == XMLHttpRequest.DONE ) {
            if (xmlhttp.status == 200) {
              var response = JSON.parse(xmlhttp.response)
              App.cable.subscriptions.remove({ channel: "TokensChannel",
                                               room_id: roomID });
              window.location.replace(response.url); // Redirect the current view
            }
            else if (xmlhttp.status == 400) {
              alert('There was an error 400');
            }
            else {
              alert('something else other than 200 was returned');
            }
          }
        };

        // Make User login POST request
        xmlhttp.open(
          "POST",
          "<%= Rails.application.routes.url_helpers.url_for(
            host: "localhost:3000", controller: "sessions", action: "create"
          ) %>",
          true
        );

        // Add necessary headers (like `csrf_meta_tags`) before sending POST request
        xmlhttp.setRequestHeader('X-CSRF-Token', csrfToken);
        xmlhttp.setRequestHeader("Content-Type", "application/json");
        xmlhttp.send(JSON.stringify(userData));
      }
    });

Really there is only two actions in this ActionCable subscription;

1. `received` required by ActionCable to handle incoming requests/events, and
2. `loginUser` our custom function

`loginUser` does the following:

- Handles incoming data to build a new data object `userData` to POST back to
  our application, which contains User information; `user_email` &
  `user_password_token`; required to login over AJAX using an authentication
  Token as the password (since its somewhat insecure, and passwords are usually
  hashed; meaning that they unknown since they cannot be reversed)

- Creates a `new XMLHttpRequest()` object to POST without jQuery, that sends a
  POST request at the JSON login URL with the `userData` as login information,
  whilst also appending the current HTML page CSRF token; e.g.

    <%= csrf_meta_tags %>

  _Otherwise the JSON request would fail without it_

- The `xmlhttp.onreadystatechange` callback function that is executed on a
  response back from the `xmlhttp.send(...)` function call. It will unsubscribe
  the User from the current room, since it is no longer needed, and redirect the
  current page to the "Welcomw page" it received back in its response. Otherwise
  it alerts the User something failed or went wrong

This will produce the following kind of application

_An image demonstrating the application, using multiple private browser sessions
to log in the other request browsers via their given URLs._

The only this solution does not address is the rolling room token generation,
which would either require either a JavaScript library to generate/regenerate
the URL with the Room Token or a Controller Action that return a regenerated
QRCode as either image or HTML that can be immediately displayed within the
page. Either method still requires you to have some JavaScript that closes the
current connection and opens a new one with a new room/session token that can
used so that only it can receive mesages from, after a certain amount of time.

**References:**

- [Action Cable Overview — Ruby on Rails Guides](http://edgeguides.rubyonrails.org/action_cable_overview.html)
- [whomwah/rqrcode: A Ruby library that encodes QR Codes](https://github.com/whomwah/rqrcode)
- [Module: SecureRandom (Ruby 2_2_1)](https://ruby-doc.org/stdlib-2.2.1/libdoc/securerandom/rdoc/SecureRandom.html#method-c-urlsafe_base64)
- [#352 Securing an API - RailsCasts](http://railscasts.com/episodes/352-securing-an-api?view=asciicast)
