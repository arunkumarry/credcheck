# frozen_string_literal: true

# Exercises the three ruby_llm prompt-caching controls against the real
# Anthropic API and prints the token buckets so you can see what each does:
#
#   with_caching        -> automatic caching (no explicit boundary)
#   without_caching     -> caching disabled (baseline)
#   cache_until_here!   -> explicit cache boundary on the system prompt
#
# Each mode uses its OWN system prompt (tagged per mode) so the caches don't
# cross-contaminate, and calls TWICE so you can see write-then-read.
#
# Run:  RUN_CACHE_TEST=1 bin/rails runner scratch/cache_modes_test.rb
#   or: require "./scratch/cache_modes_test"; CacheModesTest.run
module CacheModesTest
  MODEL = "claude-haiku-4-5-20251001"

  # Padded so the prefix clears Haiku's ~2048-token minimum cacheable size.
  def self.system_prompt(tag)
    <<~SYS + ("\nRule: recommend only held cards; reward_amount is a pure number. " * 450)
      [#{tag}] You are an expert Indian credit-card rewards advisor.
    SYS
  end

  QUESTION = "Purchase: dining, amount 2500. One short line: which card and why?"

  def self.buckets(res)
    t = res.tokens
    format("input=%-5s output=%-4s cache_write=%-6s cache_read=%-6s",
           t.input.inspect, t.output.inspect, t.cache_write.inspect, t.cache_read.inspect)
  end

  # mode: :with_caching | :without_caching | :cache_until_here
  def self.one_call(mode, tag)
    chat = RubyLLM.chat(model: MODEL, provider: :anthropic, assume_model_exists: true)

    case mode
    when :with_caching     then chat.with_caching
    when :without_caching  then chat.without_caching
    when :cache_until_here then chat.with_caching
    end

    chat.add_message(role: :system, content: system_prompt(tag))
    chat.cache_until_here! if mode == :cache_until_here

    chat.ask(QUESTION)
  end

  def self.run
    puts "ruby_llm #{RubyLLM::VERSION} | model #{MODEL}\n\n"

    %i[with_caching without_caching cache_until_here].each do |mode|
      tag = "#{mode}-#{Time.now.to_i}" # unique prefix per mode/run => isolated cache
      puts "=== #{mode} ==="
      2.times do |i|
        res = one_call(mode, tag)
        puts "  call ##{i + 1}: #{buckets(res)}"
      end
      puts
    end

    puts <<~NOTE
      Expected:
        with_caching      -> automatic; watch whether call #2 shows cache_read
        without_caching   -> cache_write / cache_read stay nil on both calls
        cache_until_here  -> call #1 cache_write>0, call #2 cache_read>0
      Cross-check the same numbers at console.anthropic.com -> Usage / Logs.
    NOTE
  end
end

CacheModesTest.run if ENV["RUN_CACHE_TEST"]
