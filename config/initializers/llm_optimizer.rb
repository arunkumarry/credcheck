# frozen_string_literal: true

# LlmOptimizer initializer
# Run `rails generate llm_optimizer:install` to regenerate this file.
#
# Docs: https://github.com/arunkumar/llm_optimizer

LlmOptimizer.configure do |config|
  # --- Feature flags ---
  # All optimizations are off by default. Enable what you need.
  config.compress_prompt    = true  # strip stop words before sending to LLM
  config.use_semantic_cache = true  # cache responses by vector similarity in Redis
  config.manage_history     = false  # summarize old messages when over token budget

  # --- Model routing ---
  # :auto classifies each prompt; :simple or :complex forces a tier
  config.route_to      = :auto
  config.simple_model  = "qwen2.5:latest"
  config.complex_model = "claude-haiku-4-5-20251001"

  # --- Redis (required only if use_semantic_cache: true) ---
  config.redis_url = ENV.fetch("REDIS_URL", nil)

  # --- Tuning ---
  config.similarity_threshold = 0.96   # cosine similarity cutoff for a cache hit
  config.token_budget         = 4000   # token limit before history summarization kicks in
  config.cache_ttl            = 86_400 # cache entry TTL in seconds (default: 24h)
  config.timeout_seconds      = 5 # timeout for embedding / external API calls

  # --- Logging ---
  config.logger        = Rails.logger
  config.debug_logging = Rails.env.development?

  # --- LLM caller (required) ---
  # Wire this up to however your app already calls the LLM.
  #
  # Example with ruby-openai:
  #   config.llm_caller = ->(prompt, model:) {
  #     OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
  #       .chat(parameters: { model: model, messages: [{ role: "user", content: prompt }] })
  #       .dig("choices", 0, "message", "content")
  #   }
  #
  # Example with a shared service object:
  config.llm_caller = ->(prompt, model:, tools: nil, schema: nil) {
    model ||= "claude-haiku-4-5-20251001"
    provider = if model.include?("claude") then :anthropic
    elsif model.include?("gpt") then :openai
    elsif model.include?("gemini") then :gemini
    else :ollama
    end
    chat = RubyLLM.chat(model: model, provider: provider, assume_model_exists: true)
    chat.with_caching # automatic provider-level prompt caching (Anthropic, OpenRouter, ...)
    chat.with_tools(*tools) if tools.present?
    chat.with_schema(schema) if schema.present?

    res = chat.ask(prompt)
    {
      content: res.content,
      input_tokens: res.input_tokens,
      output_tokens: res.output_tokens,
      # ruby_llm >= 1.15 splits cache buckets: cache_read_tokens (was cached_tokens)
      cached_tokens: res.cache_read_tokens
    }
  }

  config.embedding_caller = ->(text) {
    response = RubyLLM.embed(text, provider: :gemini, model: "gemini-embedding-001")
    response.vectors
  }

  # Classifier caller — optional, improves routing accuracy for ambiguous prompts
  # Falls back to word-count heuristic if not set or if the call fails
  # config.classifier_caller = ->(prompt) {
  #   RubyLLM.chat(model: "gemini-1.5-flash", provider: :gemini, assume_model_exists: true)
  #     .ask(prompt).content.strip.downcase
  # }
  #
  # config.llm_caller = lambda { |_prompt, **_kwargs|
  #   raise NotImplementedError, "[llm_optimizer] llm_caller is not configured. " \
  #                              "Edit config/initializers/llm_optimizer.rb and wire it to your LLM client."
  # }

  # --- Embeddings caller (optional) ---
  # Only needed if use_semantic_cache: true.
  # If omitted, falls back to OpenAI via ENV["OPENAI_API_KEY"].
  #
  # Example:
  #   config.embedding_caller = ->(text) { EmbeddingService.embed(text) }
  #
  # --- Routing classifier (optional) ---
  # When set, ambiguous prompts are classified by a cheap LLM instead of
  # falling back to the word-count heuristic. Unambiguous signals (code blocks,
  # keywords) still bypass the classifier for speed.
  #
  # Example:
  #   config.classifier_caller = ->(prompt) {
  #     RubyLLM.chat(model: "amazon.nova-micro-v1:0", assume_model_exists: true)
  #       .ask(prompt).content.strip.downcase
  #   }
  #
  # config.classifier_caller = nil

  # --- Messages caller (optional) ---
  # Messages caller for history manager/conversation summary - Optional
  # config.system_prompt = "You are a helpful person who gives responses in a non harmful way. " \
  #                  "If any serious question is asked, handle it in effectively."
  # OpenAI implmeentation -
  # config.messages_caller = ->(messages, model:) {
  #   response = $openai.chat(
  #     parameters: {
  #       model: model,
  #       messages: messages.map { |m| { role: m[:role], content: m[:content] } }
  #     }
  #   )
  #   response.dig("choices", 0, "message", "content")
  # }

  # RubyLLM implementation -
  config.messages_caller = ->(messages, model:, tools: nil, schema: nil) {
    model ||= "claude-haiku-4-5-20251001"
    provider = if model.include?("claude") then :anthropic
    elsif model.include?("gpt") then :openai
    elsif model.include?("gemini") then :gemini
    else :ollama
    end
    chat = RubyLLM.chat(model: model, provider: provider, assume_model_exists: true)
    chat.with_caching
    chat.with_tools(*tools) if tools.present?
    chat.with_schema(schema) if schema.present?

    if provider == :ollama
      chat.with_params(format: :json)
    end

    messages[0..-2].each do |m|
      chat.add_message(role: m[:role].to_s, content: m[:content].gsub(/\n{3,}/, "\n\n"))
      # Cache everything up to the system prompt (e.g. for Anthropic) to save tokens
      chat.cache_until_here! if m[:role].to_s == "system"
    end
    res = chat.ask(messages.last[:content])
    {
      content: res.content,
      input_tokens: res.input_tokens,
      output_tokens: res.output_tokens,
      # ruby_llm >= 1.15 splits cache buckets: cache_read_tokens (was cached_tokens)
      cached_tokens: res.cache_read_tokens
    }
  }

  # Anthropic implementation -
  # config.messages_caller = ->(messages, model:) {
  #   # Anthropic separates system messages from the messages array
  #   system_msg = messages.find { |m| m[:role] == "system" }&.dig(:content)
  #   chat_msgs  = messages.reject { |m| m[:role] == "system" }
  #                       .map { |m| { role: m[:role], content: m[:content] } }

  #   response = $anthropic.messages(
  #     model: model,
  #     max_tokens: 1024,
  #     system: system_msg,
  #     messages: chat_msgs
  #   )
  #   response["content"].first["text"]
  # }
end
