# LinkedIn post — Prompt caching with ruby_llm (continuation)

A follow-up to my last post on cutting LLM costs.

I mentioned I had opened a PR to support prompt caching natively in RubyLLM.

An update: Carmine Paolino shipped a cleaner, native prompt-caching API — one that works across Anthropic, OpenRouter, Bedrock and more — which is honestly a better outcome than my original approach. I spent this week testing it on my own workload, and the results were worth writing up.

A quick recap of why this matters: in my use case almost all the "weight" of every request is a large, static system prompt. The user's actual question is tiny. Re-sending those same thousands of tokens on every call is pure waste — and that's exactly what prompt caching removes.

In RubyLLM it's now easy to use. Mark where the stable part ends:

    chat = RubyLLM.chat(model: MODEL, provider: :anthropic)
    chat.add_message(role: :system, content: SYSTEM)
    chat.cache_until_here!   # mark the system prompt as the cache boundary
    chat.ask(user_question)  # only this is "fresh" each call

Or let it cache the stable prefix automatically:

    chat = RubyLLM.chat(model: MODEL, provider: :anthropic).with_caching
    chat.add_message(role: :system, content: SYSTEM)
    chat.ask(user_question)

There are three controls: cache_until_here! for an explicit boundary, with_caching for automatic prefix caching, and without_caching to turn it off.

The payoff, measured on Claude Haiku 4.5 with a ~7,700-token system prompt reused across calls: the first call writes the cache once, and every call after reads it at one-tenth the input price. Across 1,000 requests, serving that system prompt drops from roughly $7.70 to $0.78 — about 90% cheaper, for identical output.

One caveat worth knowing before you test it: there's a minimum. Anthropic only caches a prefix once it clears ~2,048 tokens on Haiku (about 1,024 on Sonnet/Opus). My first run sat just under that line and showed zero cache hits — confusing until I made the prompt larger and it worked instantly.

Appreciate the acknowledgement from Carmine for the work.
