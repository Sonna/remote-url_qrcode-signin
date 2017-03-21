class WelcomeController < ApplicationController
  def show
    @user = current_user
    redirect_to root_path unless current_user
  end
end
