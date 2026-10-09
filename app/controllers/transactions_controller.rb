class TransactionsController < ApplicationController
  def index
    @transactions = Current.user.transactions.order(created_at: :desc)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def update
    @transaction = Current.user.transactions.find(params[:id])
    @transaction.update(transaction_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to transactions_path }
    end
  end

  private

  def transaction_params
    params.expect(transaction: [ :complete ])
  end
end
