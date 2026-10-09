class CreateDocumentEmbeddings < ActiveRecord::Migration[8.0]
  def change
    create_table :document_embeddings do |t|
      t.string :document_name
      t.text :content
      t.json :vector

      t.timestamps
    end
  end
end
