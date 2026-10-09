module Embedding
  class VectorStore
    def self.add(document_name, content, vector)
      Document.create!(
        title: document_name,
        content: content,
        embedding: vector
      )
    end

    def self.search(query, document_prefix: nil, top_k: 5)
      embedder = Embedding.new
      query_vec = embedder.embed_text(query)
      return [] unless query_vec

      scope = Document.all

      if document_prefix.present?
        scope = scope.where("title LIKE ?", "#{document_prefix}%")
      end

      # neighbor gem provides nearest_neighbors
      matches = scope.nearest_neighbors(:embedding, query_vec, distance: "cosine").first(top_k)

      context = matches.map { |m| m.content }.join("\n")
      { context: context, source_chunks: matches }
    end
  end
end
