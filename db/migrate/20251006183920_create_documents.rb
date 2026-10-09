class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.string :title
      t.text :content
      t.string :source_url

      # pgvector column
      t.column :embedding, :vector, limit: 1536

      t.timestamps
    end
  end
end
