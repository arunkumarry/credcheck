module Retriever
  class RagPromptBuilder
    SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that answers questions strictly based on the provided document excerpts.
      - If the answer is not clearly contained in the excerpts, say you don't know.
      - Do not invent details.
    PROMPT

    def self.build(query:, chunks:)
      context = chunks.map.with_index(1) do |chunk, i|
          <<~CHUNK
          [Source #{i}]
          #{chunk.content}
        CHUNK
      end.join("\n\n")

      <<~PROMPT
        #{SYSTEM_PROMPT}
  
        Context:
        #{context}
  
        Question: #{query}

        Answer in one clear paragraph, and reference which source(s) you used.
      PROMPT
    end
  end
end