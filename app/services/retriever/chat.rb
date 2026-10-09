module Retriever
  class Chat
    def self.answer(query)
      chat = RubyLLM.chat(
        model: "llama3",
        provider: :ollama,
        assume_model_exists: true
      )

      matched_context = Embedding::VectorStore.search(query)

      response = chat.ask(<<~PROMPT)
        Context:
        #{matched_context[:context]}
      
        Question: #{query}
      
        Please respond with a JSON object containing:
        {
          "answer": "Your full answer here",
          "fee": "Numeric value only or null if not specified"
        }
      PROMPT

      json_response = response.content
      puts json_response
      begin
        parsed = JSON.parse(json_response)
        answer = parsed["answer"]
        fee = parsed["fee"]&.to_i  # convert fee string to integer, or nil if not present
      rescue JSON::ParserError => e
        # Handle the case where LLM does not return valid JSON
        puts "Parsing error: #{e.message}"
        answer = json_response
        fee = nil
      end
    end
  end
end
