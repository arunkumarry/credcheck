class WelcomeController < ApplicationController
  allow_unauthenticated_access
  def show
    if Current.user
      @transactions = Current.user.transactions.order(created_at: :desc).limit(5)
    end
  end
end
