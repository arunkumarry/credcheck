module Agents
  module Tools
    # Agent tool: freshly announced sales / offer events via SerpApi Google News.
    class NewsSearch < RubyLLM::Tool
      description <<~DESC
        Search Google News for freshly announced sale events or limited-time
        card offers (e.g. "Amazon Great Indian Festival bank offers"). Call this
        when timing matters and a sale might change the best card choice. Returns
        hits with [S#] citation tags you must reference in your final answer.
      DESC

      parameter :query, description: "News search query about a sale event or offer announcement"

      def initialize(client:, trace:)
        @client = client
        @trace = trace
        super()
      end

      def execute(query:)
        hits = @client.news(query, num: 4).first(4)
        @trace.log_step(tool: "Google News", query: query, count: hits.size)
        return "No recent news found for '#{query}'." if hits.empty?

        hits.map do |h|
          tag = @trace.cite(h)
          "[#{tag}] #{h.title} (#{h.source})"
        end.join("\n")
      end
    end
  end
end
