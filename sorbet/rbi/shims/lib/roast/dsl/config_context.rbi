# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ConfigContext

      # Configure all cogs globally with shared settings
      #
      # Apply configuration that affects all cog instances in the workflow. Configuration
      # specified in `global` applies to every cog, but can be overridden by cog-specific
      # configuration.
      #
      # ### Usage
      # ```ruby
      # config do
      #   global do
      #     # Configuration here applies to all cogs
      #   end
      # end
      # ```
      #
      # ### Available Options (Common to All Cogs)
      #
      # Apply configuration within the block passed to `global`:
      #
      # #### Configure asynchronous execution
      # - `async!` - Run the cog asynchronously in the background
      # - `no_async!` (alias `sync!`) - Run the cog synchronously (default)
      #
      # #### Configure failure behavior
      # - `abort_on_failure!` - Abort the entire workflow immediately if this cog fails (default)
      # - `no_abort_on_failure!` (alias `continue_on_failure!`) - Continue the workflow even if this cog fails
      #
      # #### Configure the working directory
      # - `working_directory(path)` - Set the working directory for external commands invoked by the cog
      # - `use_current_working_directory!` - Use the current working directory
      #
      #: () {() [self: Roast::DSL::Cog::Config] -> void} -> void
      def global(&block); end

      # Configure the `call` cog
      #
      # The `call` cog invokes a named execution scope with a provided value.
      #
      # ### Usage
      # - `call { &blk }` - Apply configuration to all instances of the `call` cog
      # - `call(:name) { &blk }` - Apply configuration to the `call` cog instance named `:name`
      # - `call(/regexp/) { &blk }` - Apply configuration to any `call` cog whose name matches `/regexp/`
      #
      # ### Available Options
      #
      # Apply configuration within the block passed to `call`:
      #
      # #### Configure asynchronous execution
      # - `async!` - Run the cog asynchronously in the background
      # - `no_async!` (alias `sync!`) - Run the cog synchronously (default)
      #
      # #### Configure failure behavior
      # - `abort_on_failure!` - Abort the entire workflow immediately if this cog fails (default)
      # - `no_abort_on_failure!` (alias `continue_on_failure!`) - Continue the workflow even if this cog fails
      #
      #: (?(Symbol | Regexp)?) {() [self: Roast::DSL::SystemCogs::Call::Config] -> void} -> void
      def call(name = nil, &block); end

      # Configure the `map` cog
      #
      # The `map` cog executes a scope for each item in a collection, with support for
      # parallel execution.
      #
      # ### Usage
      # - `map { &blk }` - Apply configuration to all instances of the `map` cog
      # - `map(:name) { &blk }` - Apply configuration to the `map` cog instance named `:name`
      # - `map(/regexp/) { &blk }` - Apply configuration to any `map` cog whose name matches `/regexp/`
      #
      # ### Available Options
      #
      # Apply configuration within the block passed to `map`:
      #
      # #### Configure parallel execution
      # - `parallel(n)` - Execute up to `n` iterations concurrently (pass `0` for unlimited)
      # - `parallel!` - Execute all iterations concurrently with no limit
      # - `no_parallel!` - Execute iterations serially, one at a time (default)
      #
      # #### Configure asynchronous execution
      # - `async!` - Run the cog asynchronously in the background
      # - `no_async!` (alias `sync!`) - Run the cog synchronously (default)
      #
      # NOTE: parallel processing of the elements passed to the `map` cog is distinct from asynchronous execution of
      # the `map` cog itself. Use the `parallel!` setting to process multiple items concurrently from the iterable
      # provided to `map`, and `no_parallel!` to process each item one-at-a-time. Use `async`, on the other hand,
      # to allow the next cog in the workflow after `map` to begin running while the map is still processing items.
      # Otherwise, the nect cog will not start until `map` has completed processing all items.
      # You can use async and no_parallel, or no_async and parallel, or both, or neither, depending on your needs.
      #
      # #### Configure failure behavior
      # - `abort_on_failure!` - Abort the entire workflow immediately if this cog fails (default)
      # - `no_abort_on_failure!` (alias `continue_on_failure!`) - Continue the workflow even if this cog fails
      #
      #: (?(Symbol | Regexp)?) {() [self: Roast::DSL::SystemCogs::Map::Config] -> void} -> void
      def map(name = nil, &block); end

      # Configure the `repeat` cog
      #
      # The `repeat` cog executes a scope multiple times in a loop, with each iteration's
      # output becoming the next iteration's input.
      #
      # ### Usage
      # - `repeat { &blk }` - Apply configuration to all instances of the `repeat` cog
      # - `repeat(:name) { &blk }` - Apply configuration to the `repeat` cog instance named `:name`
      # - `repeat(/regexp/) { &blk }` - Apply configuration to any `repeat` cog whose name matches `/regexp/`
      #
      # ### Available Options
      #
      # Apply configuration within the block passed to `repeat`:
      #
      # #### Configure asynchronous execution
      # - `async!` - Run the cog asynchronously in the background
      # - `no_async!` (alias `sync!`) - Run the cog synchronously (default)
      #
      # #### Configure failure behavior
      # - `abort_on_failure!` - Abort the entire workflow immediately if this cog fails (default)
      # - `no_abort_on_failure!` (alias `continue_on_failure!`) - Continue the workflow even if this cog fails
      #
      #: (?(Symbol | Regexp)?) {() [self: Roast::DSL::SystemCogs::Repeat::Config] -> void} -> void
      def repeat(name = nil, &block); end

      # Configure the `agent` cog
      #
      # The `agent` cog runs a coding agent on the local machine with access to local files,
      # tools, and MCP servers. It is designed for coding tasks and any work requiring local
      # filesystem access. The `agent` cog supports automatic session resumption across invocations.
      #
      # ### Usage
      # - `agent { &blk }` - Apply configuration to all instances of the `agent` cog
      # - `agent(:name) { &blk }` - Apply configuration to the `agent` cog instance named `:name`
      # - `agent(/regexp/) { &blk }` - Apply configuration to any `agent` cog whose name matches `/regexp/`
      #
      # ### Available Options
      #
      # Apply configuration within the block passed to `agent`:
      #
      # #### Configure the agent provider
      # - `provider(symbol)` - Set the agent provider (e.g., `:claude`)
      # - `use_default_provider!` - Use the default provider (`:claude`)
      #
      # #### Configure the base command used to run the coding agent
      # - `command(string_or_array)` - Set the base command for invoking the agent
      # - `use_default_command!` - Use the provider's default command
      #
      # #### Configure the LLM model the agent should use
      # - `model(string)` - Set the model to use
      # - `use_default_model!` - Use the provider's default model
      #
      # #### Configure the system prompt
      # - `replace_system_prompt(string)` - Completely replace the agent's default system prompt
      # - `no_replace_system_prompt!` - Don't replace the default system prompt (default)
      # - `append_system_prompt(string)` - Append a prompt component to the agent's system prompt
      # - `no_append_system_prompt!` - Don't append to the system prompt (default)
      #
      # #### Configure the working directory
      # - `working_directory(path)` - Set the working directory for agent execution
      # - `use_current_working_directory!` - Use the current working directory
      #
      # #### Configure permissions
      # - `apply_permissions!` - Apply project and user-level permissions when running the agent
      # - `skip_permissions!` (alias `no_apply_permissions!`) - Skip permissions (default)
      #
      # #### Configure display output
      # - `show_prompt!` - Display the user prompt
      # - `no_show_prompt!` - Don't display the user prompt (default)
      # - `show_progress!` - Display agent's in-progress messages (default)
      # - `no_show_progress!` - Don't display agent's in-progress messages
      # - `show_response!` - Display the agent's final response (default)
      # - `no_show_response!` - Don't display the agent's final response
      # - `show_stats!` - Display agent operation statistics (default)
      # - `no_show_stats!` - Don't display agent operation statistics
      # - `display!` - Display all output (enables all show_ options)
      # - `no_display!` (alias `quiet!`) - Hide all output (disables all show_ options)
      #
      # #### Configure debugging
      # - `dump_raw_agent_messages_to(filename)` - Dump raw agent messages to a file for debugging
      #
      # #### Configure asynchronous execution
      # - `async!` - Run the cog asynchronously in the background
      # - `no_async!` (alias `sync!`) - Run the cog synchronously (default)
      #
      # #### Configure failure behavior
      # - `abort_on_failure!` - Abort the entire workflow immediately if this cog fails (default)
      # - `no_abort_on_failure!` (alias `continue_on_failure!`) - Continue the workflow even if this cog fails
      #
      # #### Configure the working directory
      # - `working_directory(path)` - Set the working directory in which the agent will be invoked
      # - `use_current_working_directory!` - Invoke the agent in the current working directory
      #
      #: (?(Symbol | Regexp)?) {() [self: Roast::DSL::Cogs::Agent::Config] -> void} -> void
      def agent(name = nil, &block); end

      # Configure the `chat` cog
      #
      # The chat cog provides pure LLM interaction without local system access. While it
      # cannot access local files or run local tools, it can still perform complex reasoning and
      # access any cloud-based tools and MCP servers according to the capabilities of the model and
      # the capabilities that may be provided to it by the LLM provider.
      #
      # ### Usage
      # - `chat { &blk }` - Apply configuration to all instances of the `chat` cog
      # - `chat(:name) { &blk }` - Apply configuration to the `chat` cog instance named `:name`
      # - `chat(/regexp/) { &blk }` - Apply configuration to any `chat` cog whose name matches `/regexp/`
      #
      # ### Available Options
      #
      # Apply configuration within the block passed to `chat`:
      #
      # #### Configure the LLM provider
      # - `provider(symbol)` - Set the LLM provider (e.g., `:openai`)
      # - `use_default_provider!` - Use the default provider (`:openai`)
      #
      # #### Configure the LLM model
      # - `model(string)` - Set the model to use
      # - `use_default_model!` - Use the provider's default model
      #
      # #### Configure API authentication
      # - `api_key(string)` - Set the API key for authentication
      # - `use_api_key_from_environment!` - Use API key from environment variable
      # - `base_url(string)` - Set the base URL for the API
      # - `use_default_base_url!` - Use the provider's default base URL
      #
      # #### Configure LLM parameters
      # - `temperature(float)` - Set the temperature (0.0-1.0) for response randomness
      # - `use_default_temperature!` - Use the provider's default temperature
      # - `verify_model_exists!` - Verify the model exists before invoking
      # - `no_verify_model_exists!` (alias `assume_model_exists!`) - Skip model verification (default)
      #
      # #### Configure display output
      # - `show_prompt!` - Display the user prompt
      # - `no_show_prompt!` - Don't display the user prompt (default)
      # - `show_response!` - Display the LLM's response (default)
      # - `no_show_response!` - Don't display the LLM's response
      # - `show_stats!` - Display LLM operation statistics (default)
      # - `no_show_stats!` - Don't display LLM operation statistics
      # - `display!` - Display all output (enables all show_ options)
      # - `no_display!` (alias `quiet!`) - Hide all output (disables all show_ options)
      #
      # #### Configure asynchronous execution
      # - `async!` - Run the cog asynchronously in the background
      # - `no_async!` (alias `sync!`) - Run the cog synchronously (default)
      #
      # #### Configure failure behavior
      # - `abort_on_failure!` - Abort the entire workflow immediately if this cog fails (default)
      # - `no_abort_on_failure!` (alias `continue_on_failure!`) - Continue the workflow even if this cog fails
      #
      #: (?(Symbol | Regexp)?) {() [self: Roast::DSL::Cogs::Chat::Config] -> void} -> void
      def chat(name = nil, &block); end

      # Configure the `cmd` cog
      #
      # The `cmd` cog executes shell commands and captures their output.
      #
      # ### Usage
      # - `cmd { &blk }` - Apply configuration to all instances of the `cmd` cog
      # - `cmd(:name) { &blk }` - Apply configuration to the `cmd` cog instance named `:name`
      # - `cmd(/regexp/) { &blk }` - Apply configuration to any `cmd` cog whose name matches `/regexp/`
      #
      # ### Available Options
      #
      # Apply configuration within the block passed to `cmd`:
      #
      # #### Configure command failure behavior
      # - `fail_on_error!` - Consider the cog failed if the command returns a non-zero exit status (default)
      # - `no_fail_on_error!` - Don't fail the cog on non-zero exit status (exit status still available in output)
      #
      # #### Configure display output
      # - `show_stdout!` - Write STDOUT to the console
      # - `no_show_stdout!` - Don't write STDOUT to the console (default)
      # - `show_stderr!` - Write STDERR to the console
      # - `no_show_stderr!` - Don't write STDERR to the console (default)
      # - `display!` (alias `print_all!`) - Write both STDOUT and STDERR to the console
      # - `no_display!` (alias `print_none!`, `quiet!`) - Write __no output__ to the console
      #
      # #### Configure the working directory
      # - `working_directory(path)` - Set the working directory for command execution
      # - `use_current_working_directory!` - Use the current working directory
      #
      # #### Configure asynchronous execution
      # - `async!` - Run the cog asynchronously in the background
      # - `no_async!` (alias `sync!`) - Run the cog synchronously (default)
      #
      # #### Configure failure behavior
      # - `abort_on_failure!` - Abort the entire workflow immediately if this cog fails (default)
      # - `no_abort_on_failure!` (alias `continue_on_failure!`) - Continue the workflow even if this cog fails
      #
      # #### Configure the working directory
      # - `working_directory(path)` - Set the working directory in which the command is invoked
      # - `use_current_working_directory!` - Invoke the command in the current working directory
      #
      #: (?(Symbol | Regexp)?) {() [self: Roast::DSL::Cogs::Cmd::Config] -> void} -> void
      def cmd(name_or_pattern = nil, &block); end

      # Configure the `ruby` cog
      #
      # The `ruby` cog evaluates Ruby code within the workflow context.
      #
      # ### Usage
      # - `ruby { &blk }` - Apply configuration to all instances of the `ruby` cog
      # - `ruby(:name) { &blk }` - Apply configuration to the `ruby` cog instance named `:name`
      # - `ruby(/regexp/) { &blk }` - Apply configuration to any `ruby` cog whose name matches `/regexp/`
      #
      # ### Available Options
      #
      # Apply configuration within the block passed to `ruby`:
      #
      # #### Configure asynchronous execution
      # - `async!` - Run the cog asynchronously in the background
      # - `no_async!` (alias `sync!`) - Run the cog synchronously (default)
      #
      # #### Configure failure behavior
      # - `abort_on_failure!` - Abort the entire workflow immediately if this cog fails (default)
      # - `no_abort_on_failure!` (alias `continue_on_failure!`) - Continue the workflow even if this cog fails
      #
      #: (?(Symbol | Regexp)?) {() [self: Roast::DSL::Cogs::Ruby::Config] -> void} -> void
      def ruby(name_or_pattern = nil, &block); end
    end
  end
end
