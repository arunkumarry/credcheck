class Document < ApplicationRecord
  include Pgvector

  # Tell Rails this column is a vector
  has_neighbors :embedding
  # vector :embedding, dimension: 1536
end
