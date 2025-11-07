# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Chat < Cog
        class Config < Cog::Config
          field :model, "gpt-4o-mini"
          field :api_key, ENV["OPENAI_API_KEY"]
          field :base_url, ENV.fetch("OPENAI_API_BASE_URL", "https://api.openai.com/v1")
          field :provider, :openai
          field :assume_model_exists, false
        end
      end
    end
  end
end
