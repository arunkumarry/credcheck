class CreateRecommendation < ActiveRecord::Migration[8.0]
  def change
    create_table :recommendations do |t|
      t.string :category, null: false
      t.float :amount, null: false
      t.jsonb :data, default: "{}", null: false

      t.timestamps
    end
  end
end
