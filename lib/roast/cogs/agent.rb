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
      # If the cog is configured with `record_agent_runs_to`, a record of the run is appended to that file
      # whether the run succeeds or fails.
      #
      #: (Input) -> Output
      def execute(input)
        started_at = Time.now
        begin
          output = provider.invoke(input)
          if config.show_stats?
            Event << { block: { header: "AGENT STATS", content: "#{output.stats}\nSession ID: #{output.session}" } }
          end
          output
        rescue StandardError => e
          error = e
          raise
        ensure
          record_run(input, output, error, started_at) if config.valid_record_agent_runs_to_path
        end
      end

      private

      #: (Input, Output?, StandardError?, Time) -> void
      def record_run(input, output, error, started_at)
        record = {
          started_at: started_at.utc.iso8601(3),
          finished_at: Time.now.utc.iso8601(3),
          cog: { name: anonymous? ? nil : name, path: record_path },
          provider: config.valid_provider!,
          model: config.valid_model,
          prompts: input.prompts,
          system_prompt: { append: config.valid_append_system_prompt, replace: config.valid_replace_system_prompt },
          status: run_status(output, error),
          error: error && { class: error.class.name, message: error.message },
          response: output&.response,
          session: output&.session,
          stats: output&.stats&.to_h,
        }
        path = config.valid_record_agent_runs_to_path.not_nil!
        path.dirname.mkpath
        File.write(path.to_s, "#{JSON.generate(record)}\n", mode: "a")
      end

      #: () -> Array[Hash[Symbol, untyped]]
      def record_path
        TaskContext.path.filter_map do |element|
          cog = element.cog
          execution_manager = element.execution_manager
          if cog.present?
            { cog: cog.type, name: cog.anonymous? ? nil : cog.name }
          elsif execution_manager&.scope
            { scope: execution_manager.scope, index: execution_manager.scope_index }
          end
        end
      end

      #: (Output?, StandardError?) -> String
      def run_status(output, error)
        return "timed_out" if error.is_a?(CommandRunner::TimeoutError)
        return "failed" if error || output.nil?

        "succeeded"
      end

      #: () -> Provider
      def provider
        @provider ||= case config.valid_provider!
        when :claude
          Providers::Claude.new(config)
        when :pi
          Providers::Pi.new(config)
        else
          raise UnknownProviderError, "Unknown provider: #{config.valid_provider!}"
        end
      end
    end
  end
end
