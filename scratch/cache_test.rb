# frozen_string_literal: true

# Prompt-caching smoke test for ruby_llm (upstream main) + Anthropic.
#
# Run it two ways:
#   RUN_CACHE_TEST=1 bin/rails runner scratch/cache_test.rb
#   # or in `bin/rails console`:
#   require "./scratch/cache_test"; CacheTest.run
#
# What to expect on the Claude dashboard / in the printed output:
#   Call #1  -> cache_write > 0, cache_read = 0   (cache is created)
#   Call #2  -> cache_read  > 0, cache_write = 0   (cache is hit, within 5 min TTL)
#
# IMPORTANT: Anthropic only caches a prefix once it clears the model minimum
# (~2048 tokens for Haiku, ~1024 for Sonnet/Opus). The padded system prompt
# below is deliberately long so the boundary is actually cacheable.
module CacheTest
  MODEL = "claude-haiku-4-5-20251001"

  # Long, STABLE system prompt. It must be identical across calls and big
  # enough to cross the model's minimum cacheable size, or you get 0 cache tokens.
  SYSTEM = (<<~SYS + ("\nReference rule: cards earn category-specific rewards; never invent a card. " * 120)).freeze
    You are an expert Indian credit-card rewards advisor. Recommend only from the
    user's held cards, compute reward_amount as a pure number, and return strict JSON.
  SYS

  def self.run(runs: 2)
    puts "ruby_llm #{RubyLLM::VERSION} | model #{MODEL}"
    puts "system prompt ~#{(SYSTEM.length / 4.0).round} tokens (rough)\n\n"

    runs.times do |i|
      chat = RubyLLM.chat(model: MODEL, provider: :anthropic, assume_model_exists: true)
      chat.add_message(role: :system, content: SYSTEM)
      chat.cache_until_here! # mark the system prompt as the cache boundary

      res = chat.ask("Purchase: dining, amount 2500. Which card and why? One short line.")
      t = res.tokens

      puts "── call ##{i + 1} ──"
      puts "  input        : #{t.input}"
      puts "  output       : #{t.output}"
      puts "  cache_write  : #{t.cache_write.inspect}   (created)"
      puts "  cache_read   : #{t.cache_read.inspect}   (hit)"
      puts "  reply        : #{res.content.to_s[0, 80]}"
      puts
    end

    puts "Cross-check on https://console.anthropic.com  → Usage / Logs:"
    puts "  look for 'cache creation input tokens' on call #1 and"
    puts "  'cache read input tokens' on call #2 for this API key."
  end
end

CacheTest.run if ENV["RUN_CACHE_TEST"]
