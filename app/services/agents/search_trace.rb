module Agents
  # Shared scratchpad handed to every tool the agent can call.
  #
  # It records two things as the agent works:
  #   * steps    — the live searches the agent *chose* to run (its plan in action)
  #   * citations — every source hit, tagged [S1], [S2]… so the final answer
  #                 can point back to the exact SerpApi result it used.
  #
  # Surfacing this turns an opaque LLM call into a visible
  # plan -> search -> compare -> act loop, which is the heart of the
  # AI Agents track.
  class SearchTrace
    Step = Struct.new(:tool, :query, :result_count, keyword_init: true)

    def initialize
      @steps = []
      @citations = []
    end

    attr_reader :steps, :citations

    def log_step(tool:, query:, count:)
      @steps << Step.new(tool: tool, query: query, result_count: count)
    end

    # Records a SerpApi hit and returns its citation tag (e.g. "S3").
    def cite(hit)
      tag = "S#{@citations.size + 1}"
      @citations << {
        cite: tag,
        title: hit.title,
        link: hit.link,
        source: hit.source,
        price: hit.price
      }
      tag
    end

    def any?
      @citations.any?
    end
  end
end
