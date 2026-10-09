module Agents
  module Tools
    # Agent tool: live product prices via SerpApi Google Shopping.
    class ShoppingSearch < RubyLLM::Tool
      description <<~DESC
        Search Google Shopping for the LIVE current price of a product across
        Indian merchants. Call this when the user is buying a specific product
        and you need its real market price right now. Returns price points with
        [S#] citation tags you must reference in your final answer.
      DESC

      param :query, desc: "Product search query, e.g. 'iPhone 15 128GB India'"

      def initialize(client:, trace:)
        @client = client
        @trace = trace
        super()
      end

      def execute(query:)
        hits = @client.shopping(query, num: 8).first(6)
        @trace.log_step(tool: "Google Shopping", query: query, count: hits.size)
        return "No live shopping results found for '#{query}'." if hits.empty?

        hits.map do |h|
          tag = @trace.cite(h)
          "[#{tag}] #{h.title} — #{h.price || 'price n/a'} at #{h.source}"
        end.join("\n")
      end
    end
  end
end
