class UserCardsController < ApplicationController
  def show
    @user_card = Current.user.user_cards.find(params[:id])
  end

  def new
    @available_banks = Bank.order(:name)
    @cards = params[:bank_id].present? ? Card.where(bank_id: params[:bank_id]).order(:name) : []
  end

  def create
    @card = Card.find(params[:card_id])
    @user_card = Current.user.user_cards.find_or_initialize_by(card: @card)
    
    # If they have space, make it active. Otherwise, inactive.
    if Current.user.can_add_card?
      @user_card.status = :active
      msg = "Added #{@card.name} to your wallet."
    else
      @user_card.status = :inactive
      msg = "Added #{@card.name} as inactive. You've reached your active card limit (#{Current.user.active_cards_limit})."
    end

    respond_to do |format|
      if @user_card.save
        flash.now[:notice] = msg
        format.turbo_stream
        format.html { redirect_to dashboard_path, notice: msg }
      else
        flash.now[:alert] = "Could not add card: #{@user_card.errors.full_messages.to_sentence}"
        format.turbo_stream { render turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
        format.html { redirect_to dashboard_path, alert: "Could not add card." }
      end
    end
  end

  def destroy
    @user_card = Current.user.user_cards.find(params[:id])
    @card_name = @user_card.card.name

    respond_to do |format|
      if @user_card.destroy
        flash.now[:notice] = "Removed #{@card_name} from your wallet."
        format.turbo_stream
        format.html { redirect_to dashboard_path, notice: "Removed #{@card_name} from your wallet." }
      else
        flash.now[:alert] = "Could not remove card."
        format.turbo_stream { render turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
        format.html { redirect_to dashboard_path, alert: "Could not remove card." }
      end
    end
  end
  def update
    @user_card = Current.user.user_cards.find(params[:id])
    new_status = user_card_params[:status]

    # Check limit only if trying to activate
    if new_status == "active" && !@user_card.active? && !Current.user.can_add_card?
      flash.now[:alert] = "Cannot activate. You've reached the limit of #{Current.user.active_cards_limit} active cards. Upgrade to Premium to add more!"
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
        format.html { redirect_to user_card_path(@user_card), alert: "Active card limit reached." }
      end
      return
    end

    if @user_card.update(user_card_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to user_card_path(@user_card), notice: "Card status updated." }
      end
    else
      redirect_to user_card_path(@user_card), alert: "Failed to update card status."
    end
  end

  private

  def user_card_params
    params.expect(user_card: [ :status ])
  end
end
