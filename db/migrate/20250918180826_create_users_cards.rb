class CreateUsersCards < ActiveRecord::Migration[8.0]
  def change
    create_table :users_cards do |t|
      t.references :user, null: false, foreign_key: true
      t.references :card, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.jsonb :data, default: {}

      t.timestamps
    end
  end
end
