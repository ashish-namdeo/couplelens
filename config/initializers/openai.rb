OpenAI.configure do |config|
  config.access_token = ENV["GEMINI_API_KEY"]
  config.uri_base = "https://generativelanguage.googleapis.com/v1beta/openai/"
end
