class EnableVectorExtension < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'vector' unless extension_enabled?('vector')
    
    # We already have an embedding column comment in document.rb, let's create it
    # nomic-embed-text generates 768 dimensions
    unless column_exists?(:documents, :embedding)
      add_column :documents, :embedding, :vector, limit: 768
    end
  end
end
