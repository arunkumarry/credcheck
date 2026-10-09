class DashboardsController < ApplicationController
  def show
    @user_cards = Current.user.user_cards.includes(card: :bank)
    @available_banks = Bank.all.order(:name)
  end
end
