class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  def new
    @user = User.new
  end

  def create
    @user = User.new(set_user_params)
    respond_to do |format|
      if @user.save
        start_new_session_for @user
        format.html { redirect_to after_authentication_url }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation, :first_name, :last_name)
  end
end
