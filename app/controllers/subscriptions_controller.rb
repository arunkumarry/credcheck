class SubscriptionsController < ApplicationController
  def show
    @user = Current.user
  end

  def update
    @user = Current.user
    new_plan = params[:plan]

    if %w[free premium].include?(new_plan)
      @user.update(subscription_plan: new_plan)
      redirect_to subscription_path, notice: "Successfully updated to #{new_plan.capitalize} plan!"
    else
      redirect_to subscription_path, alert: "Invalid plan selected."
    end
  end
end
