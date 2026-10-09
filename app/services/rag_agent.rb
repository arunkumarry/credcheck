require "digest"

class RagAgent
  attr_reader :citations

  def initialize(user, category, amount, coupon_codes: [], merchant: nil, product: nil)
    @user = user
    @category = category
    @amount = amount
    @coupon_codes = coupon_codes
    @merchant = merchant.presence
    @product = product.presence
    @citations = []
  end

  def call
    return [ [], {} ] if @user.user_cards.active.empty?

    # Live offers refresh daily (day is in the cache key), so a 12h TTL keeps
    # repeat lookups cheap within a day while still re-pulling SerpApi each day.
    payload = Rails.cache.fetch(cache_key, expires_in: 12.hours) do
      context = fetch_context
      result, tokens = build_prompt(context)
      { result: result, tokens: tokens, citations: @citations }
    end
    @citations = payload[:citations] || []
    [ payload[:result], payload[:tokens] ]
  rescue => e
    Rails.logger.error("RagAgent caching error: #{e.message}")
    # Fallback to no-cache if caching fails for any reason
    context = fetch_context
    build_prompt(context)
  end

  private

  def cache_key
    active_user_cards = @user.user_cards.active.order(:id)
    cards_fingerprint = active_user_cards.map { |uc| "#{uc.card_id}-#{uc.updated_at.to_i}" }.join("/")
    coupons_fingerprint = @coupon_codes.sort.join(",")
    # Live offers change daily, so the day is part of the key: a fresh day = a fresh SerpApi pull.
    "recommendation/v2/user-#{@user.id}/cat-#{@category}/amt-#{@amount}/merch-#{@merchant}/prod-#{@product}/day-#{Date.current}/coupons-#{coupons_fingerprint}/cards-#{Digest::MD5.hexdigest(cards_fingerprint)}"
  end

  def fetch_context
    active_cards = @user.user_cards.active.includes(card: :bank)
    card_list = active_cards.map do |uc|
      "- #{uc.card.name} (#{uc.card.bank.name})"
    end.join("\n")

    # 1. Start with the user's cards
    collected_context = {
      wallet: card_list,
      rules: "",
      live: ""
    }

    # 2. Fetch baseline rules (card reward structures) from the vector store
    card_names = active_cards.map { |uc| uc.card.name }
    search_query = "Reward points and offers for #{@category} on these specific cards: #{card_names.join(', ')}"
    result = Embedding::VectorStore.search(search_query, top_k: 8)
    collected_context[:rules] = result[:context] if result[:context].present?

    # 3. LIVE layer: pull current prices + card offers from SerpApi at query time.
    bank_names = active_cards.map { |uc| uc.card.bank.name }.uniq
    live = LiveSearch::OfferFinder.new(
      category: @category,
      amount: @amount,
      bank_names: bank_names,
      merchant: @merchant,
      product: @product
    ).call

    unless live.blank?
      collected_context[:live] = live.to_prompt_context
      @citations = live.citations
    end

    collected_context
  end

  def build_prompt(context)
    wallet = context[:wallet] || "No cards in wallet."
    rules = context[:rules] || "No specific rules found."
    live = context[:live].presence || "No live offers found for this purchase."

    system_instructions = <<~SYSTEM
      Expert Mode.

      USER'S ACTUAL HELD CARDS (Only recommend from this list):
      #{wallet}

      BASELINE CARD REWARD RULES (For reference, only apply if they match a card in the wallet):
      #{rules}

      LIVE SEARCH RESULTS (fetched moments ago from the web — PRIORITIZE these for current offers and prices):
      #{live}

      TASK:
      1. Provide an entry for EVERY card in the "USER'S ACTUAL HELD CARDS" list.
      2. Do NOT recommend or include any card that is not explicitly in the "USER'S ACTUAL HELD CARDS" list.
      3. If a rule belongs to a card the user DOES NOT have, IGNORE IT.
      4. A LIVE CARD OFFER only applies to a card if its bank/network matches that card. Never apply a bank's offer to another bank's card.
      5. Prefer LIVE SEARCH RESULTS over baseline rules when they conflict — live data is current.
      6. reward_amount: pure NUMBER only (total rupee value of rewards + applicable live offer for this purchase).
      7. When a figure comes from a live result, reference its [S#] marker in the reasoning.
      8. KEYS: card_name, recommended, reward_amount, rewards, reasoning, sources (array of [S#] markers used).
      9. Return ONLY a JSON array of objects.
    SYSTEM

    dynamic_prompt = <<~PROMPT
      The user is planning a purchase:
      - Category: "#{@category}"
      - Amount: #{@amount}

      Please provide the best card recommendation from the user's wallet.
    PROMPT

    # Use a schema to force the LLM to return valid, structured JSON every time
    schema = {
      type: "array",
      items: {
        type: "object",
        properties: {
          card_name: { type: "string" },
          recommended: { type: "boolean" },
          reward_amount: { type: "number" },
          rewards: { type: "string" },
          reasoning: { type: "string" },
          sources: { type: "array", items: { type: "string" } },
          coupon_codes: { type: "array", items: { type: "string" } }
        },
        required: [ "card_name", "recommended", "reward_amount", "rewards", "reasoning" ],
        additionalProperties: false
      }
    }

    # Keep the stable system instructions as a system message so the
    # messages_caller marks them as a prompt cache boundary (saves input tokens)
    result = LlmOptimizer.optimize(
      dynamic_prompt,
      messages: [
        { role: :system, content: system_instructions }
      ],
      route_to: :complex,
      cache_scope: "amt-#{@amount}",
      schema: schema
    )

    # Ensure the response is always a parsed object with string keys
    final_data = if result.response.is_a?(String)
                   parse_json(extract_json(result.response))
    else
                   result.response
    end

    # Convert all keys to strings to match view expectations
    final_data = final_data.map(&:deep_stringify_keys) if final_data.is_a?(Array)

    [ final_data, tokens(result) ]
  rescue => e
    Rails.logger.warn("RagAgent Expert Pass failed: #{e.message}. Retrying with safe mode...")

    # Safe Mode: Simplified attempt
    retry_result = LlmOptimizer.optimize(
      dynamic_prompt,
      messages: [
        { role: :system, content: system_instructions }
      ],
      cache_scope: "amt-#{@amount}:safe"
    )

    retry_data = parse_json(extract_json(retry_result.response))
    retry_data = retry_data.map(&:deep_stringify_keys) if retry_data.is_a?(Array)

    [ retry_data, tokens(retry_result) ]
  end

  private

  def extract_json(response)
    # Match the first [ and the last ] to extract the JSON array
    json_match = response.match(/\[.*\]/m) || response.match(/\{.*\}/m)
    json_str = json_match&.to_s

    if json_str.blank?
      Rails.logger.error("LLM Response content: #{response}")
      raise "No JSON found in LLM response."
    end
    json_str
  end

  def tokens(result)
    {
      input_tokens: result.input_tokens,
      output_tokens: result.output_tokens,
      compressed_tokens: result.compressed_tokens,
      cached_tokens: result.cached_tokens,
      cache_status: result.cache_status,
      model: result.model
    }
  end

  def parse_json(str)
    # Strip JS-style comments and other noise that local models sometimes include
    sanitized = str.gsub(/\/\/.*$/, "") # strip single line comments
                   .gsub(/\/\*.*?\*\//m, "") # strip multi-line comments
                   .gsub(/`/, "'") # replace backticks with single quotes

    JSON.parse(sanitized)
  rescue JSON::ParserError => e
    # If sanitization fails, try one more time by taking only the last valid JSON block
    # in case the model outputted multiple blocks.
    blocks = str.scan(/\[\s*\{.*?\}\s*\]/m)
    return JSON.parse(blocks.last) if blocks.any?

    raise e
  end
end
