# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    # Agent cog for running coding agents on the local machine
    #
    # The agent cog runs a coding agent on the local machine with access to local files,
    # tools, and MCP servers. It is designed for coding tasks and any work requiring local
    # filesystem access.
    #
    # Key capabilities:
    # - Access to local filesystem (read and write files)
    # - Can run local tools and commands
    # - Access to locally-configured MCP servers
    # - Maintain session state across multiple invocations
    # - Resume previous conversations using session identifiers
    # - Track detailed execution statistics including token usage and cost
    #
    # For pure LLM interaction without local system access, use the `chat` cog instead.
    class Agent < Cog
      # Parent class for all agent cog errors
      class AgentCogError < Roast::Error; end

      # Raised when an unknown or unsupported provider is specified
      class UnknownProviderError < AgentCogError; end

      # Raised when a required provider is not configured
      class MissingProviderError < AgentCogError; end

      # Raised when a required prompt is not provided
      class MissingPromptError < AgentCogError; end

      # The configuration object for this agent cog instance
      #
      #: Agent::Config
      attr_reader :config

      # Execute the agent with the given input and return the output
      #
      # Invokes the configured agent provider with the input prompt and any session context.
      # Optionally displays the user prompt, agent response, and execution statistics to the
      # console based on the cog's configuration.
      #
      # The agent may make multiple turns (back-and-forth exchanges) during execution,
      # especially when using tools. Each turn is counted in the execution statistics.
      #
      #: (Input) -> Output
      def execute(input)
        puts "[USER PROMPT] #{input.valid_prompt!}" if config.show_prompt?
        output = config.values[:provider].invoke(input)
        puts "[AGENT RESPONSE] #{output.response}" if config.show_response?
        puts "[AGENT STATS] #{output.stats}" if config.show_stats?
        puts "Session ID: #{output.session}" if config.show_stats?
        output
      end
    end
  end
end
