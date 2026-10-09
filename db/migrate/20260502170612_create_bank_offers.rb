class CreateBankOffers < ActiveRecord::Migration[8.0]
  def change
    create_table :bank_offers do |t|
      t.references :bank, null: false, foreign_key: true
      t.string :merchant_name
      t.text :offer_details
      t.string :category
      t.date :expiry_date
      t.string :source_url

      t.timestamps
    end
  end
end
