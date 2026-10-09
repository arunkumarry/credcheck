class AddBankIdToCards < ActiveRecord::Migration[8.0]
  def change
    add_reference :cards, :bank, null: false, foreign_key: true
  end
end
