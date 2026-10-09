module LiveSearch
  # Orchestrates the live SerpApi searches for a single purchase intent.
  #
  # Given what the user is about to buy (category, amount, optional merchant /
  # product) and the banks behind the cards in their wallet, it runs:
  #   1. one Google Shopping query for the product's live price (if a product is named)
  #   2. one Google query per bank for current card offers on this merchant/category
  #
  # The result is a bundle of structured offers + price points + citations that
  # the recommendation agent folds into its reasoning. Every figure the agent
  # cites traces back to a SerpApi hit captured here.
  class OfferFinder
    Result = Struct.new(:prices, :offers, :citations, keyword_init: true) do
      def blank?
        prices.empty? && offers.empty?
      end

      # Human/LLM-readable context block, with inline [S#] citation markers.
      def to_prompt_context
        lines = []

        if prices.any?
          lines << "LIVE MARKET PRICES (Google Shopping, fetched just now):"
          prices.first(6).each { |p| lines << "- #{p[:title]} — #{p[:price]} at #{p[:source]} [#{p[:cite]}]" }
          lines << ""
        end

        if offers.any?
          lines << "LIVE CARD OFFERS (Google search, fetched just now):"
          offers.each { |o| lines << "- [#{o[:bank]}] #{o[:title]}: #{o[:snippet]} [#{o[:cite]}]" }
          lines << ""
        end

        lines.join("\n")
      end

      def citations_list
        citations.map { |c| "[#{c[:cite]}] #{c[:title]} — #{c[:link]}" }.join("\n")
      end
    end

    OFFERS_PER_BANK = 3

    def initialize(category:, amount:, bank_names:, merchant: nil, product: nil, client: nil)
      @category = category.to_s
      @amount = amount
      @merchant = merchant.to_s.presence
      @product = product.to_s.presence
      @bank_names = Array(bank_names).map(&:to_s).uniq.reject(&:blank?)
      @client = client || SerpApiClient.new
    end

    def call
      @cite_n = 0
      citations = []
      prices = fetch_prices(citations)
      offers = fetch_offers(citations)
      Result.new(prices: prices, offers: offers, citations: citations)
    rescue StandardError => e
      Rails.logger.error("OfferFinder failed: #{e.class} #{e.message}")
      Result.new(prices: [], offers: [], citations: [])
    end

    private

    def fetch_prices(citations)
      return [] if @product.blank?

      query = [ @product, @merchant, "price India" ].compact.join(" ")
      @client.shopping(query, num: 8).first(6).map do |hit|
        cite = next_cite(citations, hit)
        {
          title: hit.title,
          price: hit.price || "price n/a",
          extracted_price: hit.extracted_price,
          source: hit.source,
          link: hit.link,
          cite: cite
        }
      end
    end

    def fetch_offers(citations)
      target = @merchant.presence || @category.presence || "online shopping"
      month = Time.current.strftime("%B %Y")

      @bank_names.flat_map do |bank|
        query = "#{bank} credit card offer #{target} #{month}"
        @client.search(query, num: OFFERS_PER_BANK).first(OFFERS_PER_BANK).map do |hit|
          cite = next_cite(citations, hit)
          {
            bank: bank,
            title: hit.title,
            snippet: hit.snippet.to_s.truncate(240),
            link: hit.link,
            source: hit.source,
            cite: cite
          }
        end
      end
    end

    def next_cite(citations, hit)
      @cite_n += 1
      tag = "S#{@cite_n}"
      citations << { cite: tag, title: hit.title, link: hit.link, source: hit.source }
      tag
    end
  end
end
