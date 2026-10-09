class CreateCards < ActiveRecord::Migration[8.0]
  def change
    create_table :cards do |t|
      t.string :name, null: false
      t.integer :status, null: false, default: 0
      t.text :description
      t.jsonb :data, default: {}

      t.timestamps
    end
  end
end
