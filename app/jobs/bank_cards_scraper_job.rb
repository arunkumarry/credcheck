class BankCardsScraperJob < ApplicationJob
  queue_as :default

  def perform(bank)
    return unless bank.is_a?(Bank)

    query = "#{bank.name} credit cards list India"
    serp_url = "https://serpapi.com/search"
    search_context_items = []

    [0, 10, 20].each do |start_index|
      res = HTTParty.get(
        serp_url,
        query: {
          engine: "google",
          q: query,
          api_key: ENV["SERP_API_KEY"],
          start: start_index
        },
        headers: {
          "User-Agent" => "Mozilla/5.0"
        },
        timeout: 30
      )

      break unless res.success?

      organic_results = res.parsed_response["organic_results"] || res["organic_results"] || []
      break if organic_results.empty?

      search_context_items += organic_results.map { |r| "#{r['title']}: #{r['snippet']}" }
    end

    if search_context_items.empty?
      Rails.logger.error("BankCardsScraperJob: SerpApi request failed or returned no results for #{bank.name}")
      return
    end

    search_context = search_context_items.join("\n")

    chat = RubyLLM.chat(
      model: "claude-haiku-4-5",
      provider: :anthropic,
      assume_model_exists: true
    )

    prompt = <<~PROMPT
      You are an expert on credit cards. Based ONLY on the following Google search results, extract a comprehensive list of all credit cards offered by "#{bank.name}".
      Eliminate any duplicate cards or minor variations (e.g., if "Regalia" and "Regalia Card" are present, just use "Regalia").
      
      Search Results:
      #{search_context}
      
      Return ONLY a valid JSON array of strings containing the unique card names. 
      Do not include any introductory or concluding text, only the raw JSON array.
      Example: ["Regalia Gold", "Infinia", "Diners Club Black"]
    PROMPT

    response = chat.ask(prompt)
    json_str = response.content.match(/\[.*\]/m)&.to_s
    
    if json_str.present?
      card_names = JSON.parse(json_str)
      
      created_count = 0
      card_names.each do |card_name|
        card = Card.find_or_initialize_by(name: card_name.strip, bank: bank)
        if card.new_record?
          card.status = :active
          card.save!
          created_count += 1
        end
      end
      Rails.logger.info("BankCardsScraperJob: Found #{card_names.size} cards, successfully added #{created_count} new cards for #{bank.name}")
    else
      Rails.logger.error("BankCardsScraperJob: Failed to extract JSON array from LLM response for #{bank.name}")
    end
  rescue => e
    Rails.logger.error("BankCardsScraperJob failed for #{bank.name}: #{e.message}")
  end
end
