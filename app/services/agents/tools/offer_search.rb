module Agents
  module Tools
    # Agent tool: live credit-card / bank offers via SerpApi Google search.
    class OfferSearch < RubyLLM::Tool
      description <<~DESC
        Search Google for CURRENT credit-card or bank offers on a merchant or
        category (e.g. "HDFC credit card offer Amazon October 2026"). Call this
        once per bank in the user's wallet to discover live discounts, cashback,
        EMI deals and coupon codes. Returns hits with [S#] citation tags you must
        reference in your final answer.
      DESC

      param :query, desc: "Offer search query including the bank name, merchant/category and current month+year"

      def initialize(client:, trace:)
        @client = client
        @trace = trace
        super()
      end

      def execute(query:)
        hits = @client.search(query, num: 4).first(4)
        @trace.log_step(tool: "Google (offers)", query: query, count: hits.size)
        return "No live offers found for '#{query}'." if hits.empty?

        hits.map do |h|
          tag = @trace.cite(h)
          "[#{tag}] #{h.title}: #{h.snippet.to_s.truncate(220)} (#{h.source})"
        end.join("\n")
      end
    end
  end
end
