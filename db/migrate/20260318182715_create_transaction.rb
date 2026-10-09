class CreateTransaction < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.string :category, null: false
      t.float :amount, null: false
      t.references :user,null: false, foreign_key: true
      t.references :recommendation,null: false, foreign_key: true
      t.references :card, null: false, foreign_key: true
      t.boolean :complete, null: false, default: true
      t.integer :status, null: false, default: 0
      t.float :saved_amount

      t.timestamps
    end
  end
end
