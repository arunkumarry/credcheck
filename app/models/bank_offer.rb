class BankOffer < ApplicationRecord
  belongs_to :bank, optional: true
  after_commit :index_in_vector_store, on: [:create, :update]
  after_destroy :remove_from_vector_store

  def index_in_vector_store
    embedder = Embedding::Embedding.new
    # Construct a descriptive text for embedding
    searchable_text = "Bank: #{bank&.name || 'All Banks'}. Merchant: #{merchant_name}. Offer: #{offer_details}. Category: #{category}."
    vector = embedder.embed_text(searchable_text)
    
    return unless vector

    # We use a specific prefix to distinguish bank offers from card rules
    doc_title = "BANK_OFFER:#{id}"
    doc = Document.find_or_initialize_by(title: doc_title)
    doc.content = searchable_text
    doc.embedding = vector
    doc.save!
  end

  def remove_from_vector_store
    Document.where(title: "BANK_OFFER:#{id}").destroy_all
  end
end
