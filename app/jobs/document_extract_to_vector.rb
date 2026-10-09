class DocumentExtractToVector < ApplicationJob
  queue_as :document_to_vector

  def perform
    embedder = Embedding::Embedding.new
    files = Dir.glob(Rails.root.join('tmp', 'google_files','*'))

    files.each do |file|
      content = Embedding::DocumentExtractor.extract(file)
      next if content.blank?
      vector = embedder.embed_text(content)
      title = file.split('/')[-1].gsub('.pdf', '')
      Embedding::VectorStore.add(title, content, vector)
    end
  end
end