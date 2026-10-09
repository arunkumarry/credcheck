class AllowNullBankIdOnBankOffers < ActiveRecord::Migration[8.0]
  def change
    change_column_null :bank_offers, :bank_id, true
  end
end
