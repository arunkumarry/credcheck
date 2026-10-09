module Embedding
  class Embedding
    attr_reader :client

    def initialize
      # @client = Ollama.new(
      #   credentials: { address: 'http://localhost:11434' },
      #   options: { server_sent_events: true }
      # )

      #@client = RubyLLM.embed(provider: :ollama, model: 'nomic-embed-text', assume_model_exists: true)
    end

    def embed_text(text)
      response = RubyLLM.embed(text, provider: :gemini, model: 'gemini-embedding-001')
      # response = HTTParty.post(
      #   'http://localhost:11434/api/embed',
      #   body: { model: 'nomic-embed-text', input: text }.to_json,
      #   headers: { 'Content-Type' => 'application/json' }
      # )
      if response.vectors.present?
        response.vectors
      else
        Rails.logger.error("Failed to generate embedding: #{response.message}")
        nil
      end
    end
  end
end