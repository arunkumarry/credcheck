class MakeCardIdNullableInTransactions < ActiveRecord::Migration[8.0]
  def change
    change_column_null :transactions, :card_id, true
  end
end
