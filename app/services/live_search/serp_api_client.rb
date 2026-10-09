module LiveSearch
  # Thin wrapper over the SerpApi REST API (https://serpapi.com/search).
  #
  # This is the live data layer of CredCheck: every recommendation is grounded
  # in search results fetched at query time, so pricing and card offers reflect
  # what is live on the web *right now* rather than a stale scrape.
  #
  # Supported engines: :google, :google_shopping, :google_news.
  # Each returns a normalized array of hits so callers never touch raw JSON.
  class SerpApiClient
    BASE_URI = "https://serpapi.com/search".freeze
    DEFAULT_TIMEOUT = 20
    MAX_ATTEMPTS = 2

    class ConfigurationError < StandardError; end

    Hit = Struct.new(:title, :snippet, :link, :source, :price, :extracted_price, keyword_init: true)

    def initialize(api_key: ENV["SERP_API_KEY"], location: "India", gl: "in", hl: "en")
      @api_key = api_key
      @location = location
      @gl = gl
      @hl = hl
    end

    # Plain Google web search. Best for "<merchant> <bank> credit card offer <month>".
    def search(query, num: 10)
      results = request(engine: "google", q: query, num: num, location: @location)
      organic = results["organic_results"] || []
      organic.map do |r|
        Hit.new(
          title: r["title"],
          snippet: r["snippet"],
          link: r["link"],
          source: r["source"] || host_of(r["link"]),
          price: nil,
          extracted_price: nil
        )
      end
    end

    # Google Shopping. Returns live prices across merchants for a product query.
    def shopping(query, num: 10)
      results = request(engine: "google_shopping", q: query, num: num, location: @location)
      items = results["shopping_results"] || []
      items.map do |r|
        Hit.new(
          title: r["title"],
          snippet: r["snippet"],
          link: r["product_link"] || r["link"],
          source: r["source"],
          price: r["price"],
          extracted_price: r["extracted_price"]
        )
      end
    end

    # Google News. Useful for freshly announced offers / sales events.
    def news(query, num: 10)
      results = request(engine: "google_news", q: query, num: num)
      items = results["news_results"] || []
      items.map do |r|
        Hit.new(
          title: r["title"],
          snippet: r["snippet"],
          link: r["link"],
          source: r.dig("source", "name") || host_of(r["link"]),
          price: nil,
          extracted_price: nil
        )
      end
    end

    private

    def request(engine:, **params)
      raise ConfigurationError, "SERP_API_KEY is not set" if @api_key.blank?

      attempts = 0
      begin
        attempts += 1
        response = HTTParty.get(
          BASE_URI,
          query: { engine: engine, api_key: @api_key, gl: @gl, hl: @hl }.merge(params).compact,
          headers: { "User-Agent" => "Mozilla/5.0 (CredCheck)" },
          timeout: DEFAULT_TIMEOUT
        )

        unless response.success?
          Rails.logger.error("SerpApiClient #{engine} HTTP #{response.code}: #{response.body&.truncate(200)}")
          return {}
        end

        parsed = response.parsed_response
        if parsed.is_a?(Hash) && parsed["error"].present?
          Rails.logger.error("SerpApiClient #{engine} error: #{parsed['error']}")
          return {}
        end

        parsed.is_a?(Hash) ? parsed : {}
      rescue Net::ReadTimeout, Net::OpenTimeout, Timeout::Error => e
        if attempts < MAX_ATTEMPTS
          Rails.logger.warn("SerpApiClient #{engine} timeout (attempt #{attempts}), retrying...")
          retry
        end
        Rails.logger.error("SerpApiClient #{engine} timed out after #{attempts} attempts: #{e.message}")
        {}
      end
    rescue StandardError => e
      Rails.logger.error("SerpApiClient #{engine} request failed: #{e.class} #{e.message}")
      {}
    end

    def host_of(url)
      URI.parse(url.to_s).host
    rescue URI::InvalidURIError
      nil
    end
  end
end
