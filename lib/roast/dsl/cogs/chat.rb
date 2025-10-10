# typed: true
# frozen_string_literal: true

require "ruby_llm"

module Roast
  module DSL
    module Cogs
      class Chat < Cog
        class Output
          attr_reader :response

          def initialize(response)
            @response = response
          end
        end

        class Config < Cog::Config
          def model=(model_name)
            @values[:model] = model_name
          end

          def model
            @values[:model] || :claude_sonnet_4_5
          end

          def print_all!
            @values[:print_all] = true
          end

          def print_all?
            !!@values[:print_all]
          end
        end

        #: (String) -> Output
        def execute(input)
          response = chat(input)
          puts response if @config.print_all?
          Output.new(response)
        end

        private

        def chat(prompt)
          context = RubyLLM.context do |ctx|
            ctx.openai_api_key = api_key_from_config
            ctx.openai_api_base = Roast::DSL::Config.get(:llm, :chat, :base_url)
          end

          chat_client = context.chat(
            provider: :openai,
            model: model_name,
            assume_model_exists: true,
          )

          response = chat_client.ask(prompt)
          response.content
        end

        def api_key_from_config
          cred_helper = Roast::DSL::Config.get(:llm, :chat, :cred_helper)
          out, err, stat = Open3.capture3(cred_helper) # rubocop:disable Roast/UseCmdRunner
          unless stat.success?
            raise "Failed to get API key from cred_helper: #{err}"
          end

          out.strip
        end

        def model_name
          case @config.model
          when :claude_sonnet_4_5
            "claude-sonnet-4-5"
          when :claude_opus_4
            "claude-opus-4"
          else
            raise "Invalid model: #{@config.model}"
          end
        end
      end
    end
  end
end
