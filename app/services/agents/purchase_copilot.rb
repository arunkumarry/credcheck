module Agents
  # The CredCheck agent.
  #
  # Given a purchase and the user's wallet, it runs a genuine
  # plan -> search -> compare -> act loop:
  #   * PLAN    — the LLM decides which live searches it needs.
  #   * SEARCH  — it calls SerpApi tools (shopping / offers / news) itself,
  #               as many times as it judges necessary.
  #   * COMPARE — it folds live prices + offers over the baseline reward rules.
  #   * ACT     — it returns a ranked, source-cited recommendation per card.
  #
  # Unlike a hardcoded pipeline, the searches are chosen by the model at
  # runtime, which is what makes this an agent rather than a script.
  class PurchaseCopilot
    MODEL = "claude-haiku-4-5".freeze
    PROVIDER = :anthropic

    Result = Struct.new(:recommendations, :tokens, :trace, keyword_init: true)

    def initialize(user:, category:, amount:, merchant: nil, product: nil)
      @user = user
      @category = category.to_s
      @amount = amount
      @merchant = merchant.to_s.presence
      @product = product.to_s.presence
    end

    def call
      active_cards = @user.user_cards.active.includes(card: :bank)
      return Result.new(recommendations: [], tokens: {}, trace: nil) if active_cards.empty?

      trace = SearchTrace.new
      client = LiveSearch::SerpApiClient.new

      chat = RubyLLM.chat(model: MODEL, provider: PROVIDER, assume_model_exists: true)
      chat.with_instructions(system_instructions(active_cards))
      chat.with_tools(
        Tools::ShoppingSearch.new(client: client, trace: trace),
        Tools::OfferSearch.new(client: client, trace: trace),
        Tools::NewsSearch.new(client: client, trace: trace)
      )

      response = chat.ask(user_prompt)
      recommendations = parse_json(response.content)

      Result.new(recommendations: recommendations, tokens: tokens(response), trace: trace)
    end

    private

    def system_instructions(active_cards)
      wallet = active_cards.map { |uc| "- #{uc.card.name} (#{uc.card.bank.name})" }.join("\n")
      banks = active_cards.map { |uc| uc.card.bank.name }.uniq
      baseline = baseline_rules(active_cards)
      month = Time.current.strftime("%B %Y")

      <<~SYSTEM
        You are CredCheck, an expert Indian credit-card concierge. Your job: tell the
        user which card in THEIR wallet gives the best value for a specific purchase,
        using LIVE data you fetch yourself.

        USER'S WALLET (recommend ONLY from these cards):
        #{wallet}

        BASELINE REWARD RULES (reference only; may be stale — prefer live data):
        #{baseline}

        TODAY IS #{month}.

        HOW TO WORK (agent loop):
        1. PLAN which searches you need for this purchase.
        2. If a specific product is named, call shopping_search for its live price.
        3. Call offer_search once per bank in the wallet (#{banks.join(', ')}),
           including the merchant/category and "#{month}" in each query, to find
           current offers, cashback and coupon codes.
        4. If a sale event seems likely, call news_search to confirm timing.
        5. COMPARE: fold live offers + prices over the baseline rules. An offer only
           applies to a card whose bank matches the offer's bank.
        6. ACT: return your recommendation.

        OUTPUT RULES:
        - Provide one entry for EVERY card in the wallet.
        - reward_amount: a pure NUMBER — total rupee value (rewards + applicable live offer).
        - Cite the [S#] tags from tool results for any figure you take from live data.
        - Return ONLY a JSON array, no prose, with objects shaped exactly:
          {"card_name": string, "recommended": boolean, "reward_amount": number,
           "rewards": string, "reasoning": string, "sources": [string]}
      SYSTEM
    end

    def user_prompt
      parts = [ "Purchase category: #{@category}", "Amount: ₹#{@amount}" ]
      parts << "Merchant/platform: #{@merchant}" if @merchant
      parts << "Product: #{@product}" if @product
      parts << "Which card in my wallet should I use? Fetch live prices and offers first."
      parts.join("\n")
    end

    def baseline_rules(active_cards)
      card_names = active_cards.map { |uc| uc.card.name }
      query = "Reward points and offers for #{@category} on these cards: #{card_names.join(', ')}"
      result = Embedding::VectorStore.search(query, top_k: 8)
      result[:context].presence || "No baseline rules on file."
    rescue StandardError => e
      Rails.logger.warn("PurchaseCopilot baseline lookup failed: #{e.message}")
      "No baseline rules on file."
    end

    def parse_json(content)
      json = content.to_s.match(/\[.*\]/m)&.to_s
      return [] if json.blank?

      data = JSON.parse(json)
      data.is_a?(Array) ? data.map(&:deep_stringify_keys) : []
    rescue JSON::ParserError => e
      Rails.logger.error("PurchaseCopilot JSON parse failed: #{e.message}. Content: #{content.to_s.truncate(400)}")
      []
    end

    def tokens(response)
      {
        input_tokens: response.input_tokens,
        output_tokens: response.output_tokens,
        cached_tokens: response.cached_tokens,
        model: MODEL
      }
    end
  end
end
