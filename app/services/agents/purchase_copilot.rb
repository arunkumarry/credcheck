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

    Result = Struct.new(:recommendations, :tokens, :trace, :amount, keyword_init: true)

    # Listings we don't want to price against when discovering a price.
    JUNK_PATTERNS = /renew|refurb|used|second.?hand|locked|case|cover|screen|guard|protector|cable|charger/i

    def initialize(user:, category:, amount:, merchant: nil, product: nil)
      @user = user
      @category = category.to_s
      @amount = amount.presence
      @merchant = merchant.to_s.presence
      @product = product.to_s.presence
    end

    def call
      active_cards = @user.user_cards.active.includes(card: :bank)
      return Result.new(recommendations: [], tokens: {}, trace: nil, amount: @amount) if active_cards.empty?

      trace = SearchTrace.new
      client = LiveSearch::SerpApiClient.new

      # If the user didn't give an amount, discover the live price first so the
      # agent (and the stored record) have a concrete figure to work with.
      resolve_price(client, trace) if @amount.blank? && @product.present?

      chat = RubyLLM.chat(model: MODEL, provider: PROVIDER, assume_model_exists: true)
      chat.with_instructions(system_instructions(active_cards))
      chat.with_tools(
        Tools::ShoppingSearch.new(client: client, trace: trace),
        Tools::OfferSearch.new(client: client, trace: trace),
        Tools::NewsSearch.new(client: client, trace: trace)
      )

      response = chat.ask(user_prompt)
      recommendations = parse_json(response.content)

      Result.new(recommendations: recommendations, tokens: tokens(response), trace: trace, amount: @amount)
    end

    private

    # Deterministic price discovery via Google Shopping: filter out junk
    # listings (refurbished / accessories), then use the median new-unit price.
    # Recorded in the trace so it shows up as the agent's first step.
    def resolve_price(client, trace)
      query = [ @product, @merchant, "price India" ].compact.join(" ")
      hits = client.shopping(query, num: 12)
      trace.log_step(tool: "Google Shopping", query: query, count: hits.size)

      clean = hits.reject { |h| h.title.to_s.match?(JUNK_PATTERNS) }
      clean = hits if clean.empty?
      clean.first(6).each { |h| trace.cite(h) }

      prices = clean.map(&:extracted_price).compact.map(&:to_f).select(&:positive?).sort
      return if prices.empty?

      @amount = prices[prices.size / 2].round # median
      @price_discovered = true
    end

    def system_instructions(active_cards)
      wallet = active_cards.map do |uc|
        summary = uc.card.data&.dig("reward_summary").presence ||
                  "standard ~1% base reward on all spends"
        "- #{uc.card.name} (#{uc.card.bank.name}) — Reward structure: #{summary}"
      end.join("\n")
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

        HOW TO WORK (agent loop) — BE ECONOMICAL, aim for 4-5 searches TOTAL:
        1. PLAN which searches you need for this purchase.
        2. If a specific product is named, call shopping_search ONCE for its live price.
        3. Call offer_search EXACTLY ONCE per bank in the wallet (#{banks.join(', ')}),
           including the merchant/category and "#{month}" in each query. Do NOT run
           per-card variants and do NOT repeat a search you already ran.
        4. Optionally call news_search ONCE if a sale event might change the answer.
        5. COMPARE: fold live offers + prices over the baseline rules. An offer only
           applies to a card whose bank matches the offer's bank.
        6. ACT: return your recommendation. Do not keep searching once you have
           one offer result per bank.

        OUTPUT RULES:
        - Provide one entry for EVERY card in the wallet.
        - reward_amount: a pure NUMBER = total rupee value for THIS purchase =
          (the card's BASE reward rate from its Reward structure, applied to the
          amount) PLUS any applicable LIVE offer whose bank matches this card.
          ALWAYS include the base reward — NEVER return 0 for a card that earns a
          base reward. Example: a 1.5% card on a Rs.1,00,000 purchase earns at
          least Rs.1,500 even with no special offer.
        - Only add a merchant-locked offer (e.g. "5% on Flipkart") if that
          merchant is the purchase merchant. If no merchant was given, use each
          card's GENERAL base rate — never assume a merchant the user did not name.
        - In "rewards", briefly show the breakdown (base reward + offer) so the
          number is explainable.
        - recommended: set true for EXACTLY ONE card — the one with the HIGHEST
          reward_amount. Your recommendation and the numbers must agree; never flag
          a card as best while another has a higher reward_amount.
        - Cite the [S#] tags from tool results for any figure you take from live data.
        - Return ONLY a JSON array, no prose, with objects shaped exactly:
          {"card_name": string, "recommended": boolean, "reward_amount": number,
           "rewards": string, "reasoning": string, "sources": [string]}
      SYSTEM
    end

    def user_prompt
      parts = [ "Purchase category: #{@category}" ]

      if @price_discovered && @amount.present?
        parts << "Amount: ₹#{@amount} — this is the live Google Shopping price I already looked up for you; use it and do NOT search shopping again."
      elsif @amount.present?
        parts << "Amount: ₹#{@amount}"
      else
        parts << "Amount: not given — call shopping_search to find the live price, then use it."
      end

      parts << "Merchant/platform: #{@merchant}" if @merchant
      parts << "Product: #{@product}" if @product
      parts << "Which card in my wallet should I use? Use live offers for each bank."
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
      text = content.to_s
      # The model often wraps the answer in prose and inline [S#] citation
      # brackets, so a naive /\[.*\]/ would grab a citation like "[S8, S9]".
      # Prefer a fenced ```json block, else the first array-of-objects.
      json = text[/```(?:json)?\s*(\[.*?\])\s*```/m, 1] || text[/\[\s*\{.*\}\s*\]/m]
      return [] if json.blank?

      data = JSON.parse(json)
      data.is_a?(Array) ? data.map(&:deep_stringify_keys) : []
    rescue JSON::ParserError => e
      Rails.logger.error("PurchaseCopilot JSON parse failed: #{e.message}. Content: #{text.truncate(400)}")
      []
    end

    def tokens(response)
      {
        input_tokens: response.input_tokens,
        output_tokens: response.output_tokens,
        cached_tokens: (response.cache_read_tokens if response.respond_to?(:cache_read_tokens)),
        model: MODEL
      }
    end
  end
end
