# RubyLLM.configure do |config|
#   config.openai_api_key = ENV['OPENAI_API_KEY'] || Rails.application.credentials.dig(:openai_api_key)
#   # config.default_model = "gpt-4.1-nano"
#
#   # Use the new association-based acts_as API (recommended)
#   config.use_new_acts_as = true
# end

RubyLLM.configure do |config|
  # Add keys ONLY for the providers you intend to use.
  # Using environment variables is highly recommended.
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", nil)
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
  config.bedrock_api_key = ENV.fetch("AWS_ACCESS_KEY_ID", nil)
  config.bedrock_secret_key = ENV.fetch("AWS_SECRET_ACCESS_KEY", nil)
  config.bedrock_region = ENV.fetch("AWS_REGION", nil)
  config.vertexai_location = ENV.fetch("GOOGLE_CLOUD_LOCATION", nil)
  config.vertexai_project_id = ENV.fetch("GOOGLE_CLOUD_PROJECT", nil)
  config.ollama_api_base = "http://localhost:11434/v1"
  config.request_timeout = 300 # Wait up to 5 minutes for local Ollama models to generate responses
  # config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
end

# NOTE: gemini-3.5-flash is bundled in the ruby_llm model registry as of the
# post-1.16 main branch, so no custom model registration is needed anymore.
# (The old RubyLLM::Model::Info API was also renamed to RubyLLM::Model.)
