class CreateBanks < ActiveRecord::Migration[8.0]
  def change
    create_table :banks do |t|
      t.string :name
      t.text :description
      t.jsonb :data

      t.timestamps
    end
  end
end
