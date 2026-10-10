#!/usr/bin/env ruby
# frozen_string_literal: true

# CredCheck MCP server (stdio transport).
#
# Exposes CredCheck's live, SerpApi-grounded card recommendation as MCP tools so
# any MCP client (Claude Desktop, etc.) can ask "which card should I use?".
#
# Run it (from the project root):
#   bundle exec ruby mcp/credcheck_mcp_server.rb
#
# It boots the Rails app, so it uses the same .env keys (SERP_API_KEY,
# ANTHROPIC_API_KEY) and database. The wallet it reasons over belongs to the
# user in CREDCHECK_MCP_USER_EMAIL (default: demo@credcheck.in).

# --- Boot Rails quietly: keep stdout clean for the JSON-RPC protocol ---
real_stdout = $stdout.dup
$stdout.reopen($stderr) # anything printed during boot goes to stderr, not the protocol
ENV["RAILS_ENV"] ||= "development"
require_relative "../config/environment"
Rails.logger = Logger.new($stderr) # never log to stdout
$stdout.reopen(real_stdout)
$stdout.sync = true

require "fast_mcp"

module CredcheckMcp
  WALLET_EMAIL = ENV.fetch("CREDCHECK_MCP_USER_EMAIL", "demo@credcheck.in")

  def self.wallet_user
    User.find_by(email_address: WALLET_EMAIL)
  end

  def self.no_wallet_message
    "No CredCheck wallet found for '#{WALLET_EMAIL}'. Set CREDCHECK_MCP_USER_EMAIL " \
      "to an existing user, or seed the demo data (bin/rails db:seed)."
  end
end

# --- Tool: full recommendation (the agent) ---
class RecommendCardTool < FastMcp::Tool
  tool_name "recommend_card"
  description <<~DESC
    Recommend the best credit card in the user's CredCheck wallet for a purchase.
    Uses LIVE data from SerpApi: the current product price (Google Shopping) and
    this month's bank offers (Google). Returns every card ranked by rupee value,
    with the reward breakdown, reasoning, and the live sources used.
    If a product is given you can leave amount blank — the price is auto-detected.
  DESC

  arguments do
    required(:category).filled(:string).description("Purchase category, e.g. 'Electronics', 'Dining', 'Travel'")
    optional(:product).maybe(:string).description("Specific product, e.g. 'iPhone 17 256GB'. Enables live price auto-detect.")
    optional(:merchant).maybe(:string).description("Merchant/platform, e.g. 'Amazon', 'Zomato'. Unlocks merchant offers.")
    optional(:amount).maybe(:integer).description("Purchase amount in INR. Omit if a product is given (price is auto-detected).")
  end

  def call(category:, product: nil, merchant: nil, amount: nil)
    user = CredcheckMcp.wallet_user
    return CredcheckMcp.no_wallet_message unless user

    agent = RagAgent.new(user, category, amount, merchant: merchant, product: product)
    recommendations, _tokens = agent.call

    if recommendations.blank?
      return "No recommendation could be produced (is the wallet empty, or the product un-priceable?)."
    end

    best = recommendations.find { |r| r["recommended"] } || recommendations.first
    JSON.pretty_generate(
      purchase: { category: category, merchant: merchant, product: product,
                  amount: agent.resolved_amount, amount_auto_detected: amount.nil? && product.present? },
      best_card: best && best["card_name"],
      recommendations: recommendations.map { |r|
        {
          card: r["card_name"], recommended: r["recommended"],
          reward_value_inr: r["reward_amount"], rewards: r["rewards"],
          reasoning: r["reasoning"], sources: r["sources"]
        }
      },
      sources: (agent.citations || []).map { |c| { tag: c[:cite], title: c[:title], url: c[:link], source: c[:source] } }
    )
  rescue => e
    "CredCheck error: #{e.class}: #{e.message}"
  end
end

# --- Tool: standalone live price lookup (SerpApi Google Shopping) ---
class LiveProductPriceTool < FastMcp::Tool
  tool_name "live_product_price"
  description "Look up the live price of a product across Indian merchants via SerpApi Google Shopping."

  arguments do
    required(:product).filled(:string).description("Product to price, e.g. 'iPhone 17 256GB'")
    optional(:merchant).maybe(:string).description("Optional merchant to bias the query, e.g. 'Amazon'")
  end

  def call(product:, merchant: nil)
    client = LiveSearch::SerpApiClient.new
    query = [product, merchant, "price India"].compact.join(" ")
    hits = client.shopping(query, num: 10).first(8)
    return "No live prices found for '#{product}'." if hits.empty?

    prices = hits.map(&:extracted_price).compact.map(&:to_f).select(&:positive?).sort
    JSON.pretty_generate(
      query: query,
      typical_price_inr: (prices[prices.size / 2].round if prices.any?),
      offers: hits.map { |h| { title: h.title, price: h.price, source: h.source, url: h.link } }
    )
  rescue => e
    "CredCheck error: #{e.class}: #{e.message}"
  end
end

# --- Tool: list the configured wallet ---
class ListWalletTool < FastMcp::Tool
  tool_name "list_wallet"
  description "List the credit cards in the configured CredCheck wallet."

  arguments do
    # no arguments
  end

  def call
    user = CredcheckMcp.wallet_user
    return CredcheckMcp.no_wallet_message unless user

    cards = user.user_cards.active.includes(card: :bank).map do |uc|
      { card: uc.card.name, bank: uc.card.bank.name,
        reward_structure: uc.card.data&.dig("reward_summary") }
    end
    JSON.pretty_generate(wallet_owner: user.email_address, cards: cards)
  rescue => e
    "CredCheck error: #{e.class}: #{e.message}"
  end
end

server = FastMcp::Server.new(name: "credcheck", version: "1.0.0")
server.register_tools(RecommendCardTool, LiveProductPriceTool, ListWalletTool)
server.start
