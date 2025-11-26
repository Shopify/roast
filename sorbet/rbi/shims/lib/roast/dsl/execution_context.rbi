# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ExecutionContext

      # Define the output of the current execution scope
      #
      # The `outputs!` block defines the 'primary' return value of this execution scope when it is invoked
      # via the `call`, `map`, or `repeat` cogs. The block receives the current scope value and
      # index as arguments, and executes in a `Roast::DSL::CogInputContext` where you can
      # access any cog outputs from within the current scope.
      #
      # The `outputs!` block **always runs**, even if `break!` or `next!` are called within the
      # scope. It is effectively a finalizer for the execution scope (though it will not run if
      # the workflow aborts with an error).
      #
      # The alternative `outputs` block is identical to `outputs!`, but with relaxed handling of `CogOutputAccessError`s.
      # `outputs!` will raise an exception if you attempt to access a cog that did not run (e.g., due to `skip!`)
      # using its bang method for that cog -- i.e., the normal behaviour in a cog input block.
      # `outputs`, on the other hand, will swallow these `CogOutputAccessError`s.
      #
      # It is recommended to use `outputs!` as the default unless you specifically need the relaxed error handling of
      # `outputs`.
      #
      # The `outputs!` block **always runs**, even if `break!` or `next!` are called within the scope. It is
      # effectively a finalizer for the execution scope (though it will not run if the workflow aborts with an error).
      #
      # NOTE: You can only have one output block in an execution scope: either `outputs!` or `outputs` depending
      # on your requirements for that scope.
      #
      # ### Usage
      # ```ruby
      # execute(:refine_content) do
      #   chat(:improve) do |my, content, idx|
      #     my.prompt = "Improve this content (iteration #{idx}): #{content}"
      #   end
      #
      #   ruby { |_, _, idx| break! if idx >= 3 }
      #
      #   # This always runs, even when break! is called
      #   outputs! { chat!(:improve).response }
      # end
      #
      # execute do
      #   repeat(:refine, run: :refine_content) { "Initial draft content" }
      #
      #   ruby { puts "Final version: #{from(repeat!(:refine))}" }
      # end
      # ```
      #
      # ### See Also
      # - `outputs` - Relaxed error handling (returns nil for cogs that didn't run)
      # - `from` - Extract output from a `call` cog, or a single iteration of `map` or `repeat`
      # - `collect` - Collect results from a `map` or `repeat` cog
      # - `reduce` - Reduce results from a `map` or `repeat` cog
      #
      #: () {(untyped, Integer) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def outputs!(&block); end

      # Define the output of the current execution scope (relaxed error handling)
      #
      # NOTE: Unless you explicitly want the relaxed error handling, using `outputs!` is recommended.
      #
      # The `outputs` block defines the 'primary' return value of this execution scope when it is invoked
      # via the `call`, `map`, or `repeat` cogs. The block receives the current scope value and
      # index as arguments, and executes in a `Roast::DSL::CogInputContext` where you can
      # access any cog outputs from within the current scope.
      #
      # The `outputs` block **always runs**, even if `break!` or `next!` are called within the
      # scope. It is effectively a finalizer for the execution scope (though it will not run if
      # the workflow aborts with an error).
      #
      # The `outputs` variant silently handles `CogOutputAccessError`s when accessing cogs that did not run
      # (e.g., due to `skip!`), returning `nil` instead of raising an exception. This is a convenience
      # formulation for use when you know your scope may abort early, and you only need to compute an
      # `outputs` value when the scope runs fully. Use `outputs!` if you do want all such errors to be raised.
      #
      # NOTE: You can only have one output block in an execution scope: either `outputs!` or `outputs` depending
      # on your requirements for that scope.
      #
      # ### Usage
      # ```ruby
      # execute(:analyze_text) do
      #   chat(:analysis) do |my, text|
      #     my.prompt = "Analyze this text and identify key themes: #{text}"
      #   end
      #
      #   # Define what this scope returns
      #   outputs do |text|
      #     {
      #       original: text,
      #       analysis: chat!(:analysis).response,
      #       word_count: text.split.length
      #     }
      #   end
      # end
      #
      # execute do
      #   call(:process, run: :analyze_text) { "The quick brown fox jumps over the lazy dog" }
      #
      #   ruby { puts "Result: #{from(call!(:process))[:analysis]}" }
      # end
      # ```
      #
      # ### See Also
      # - `outputs!` - Raises errors when accessing cogs that did not run
      # - `from` - Extract output from a `call` cog, or a single iteration of `map` or `repeat`
      # - `collect` - Collect results from a `map` or `repeat` cog
      # - `reduce` - Reduce results from a `map` or `repeat` cog
      #
      #: () {(untyped, Integer) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def outputs(&block); end

      # Invoke a named execution scope with a provided value
      #
      # The `call` cog executes a named execution scope (defined with `execute(:name)`) with a
      # provided value and optional index. The executed scope can access this value and index
      # through cog input block parameters.
      #
      # The index parameter is primarily for compatibility, allowing a single execution scope to
      # be invoked by both `call` (with a specific index) and `map` (with iteration indices).
      #
      # ### Usage
      # ```ruby
      # execute(:summarize_article) do
      #   chat(:summary) do |my, article_text|
      #     my.prompt = "Summarize this article in 2-3 sentences: #{article_text}"
      #   end
      # end
      #
      # # The nameless execute scope is the workflow entry point
      # execute do
      #   call(:process_article, run: :summarize_article) do |my|
      #     my.value = "Long article text goes here..."
      #   end
      # end
      # ```
      #
      # ### Input Options
      #
      # Set these attributes on the `my` input object within the block.
      #
      # - `value` (required) - The value to pass to the execution scope
      # - `index` (optional) - The index value to pass to the scope (defaults to 0)
      #
      # You can also return a value from the block, which will be used as `my.value` if not set explicitly.
      #
      # ### See Also
      # - `map` - Execute a scope for each item in a collection
      # - `repeat` - Execute a scope multiple times in a loop
      # - `from` - Extract the result from the called scope
      #
      #: (?Symbol?, run: Symbol) ?{(Roast::DSL::SystemCogs::Call::Input, untyped, Integer) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def call(name = nil, run:,  &block); end

      # Execute a scope for each item in a collection
      #
      # The `map` cog executes a named execution scope (defined with `execute(:name)`) for each
      # item in a collection. Supports both serial and parallel execution modes. Each iteration
      # receives the current item as its value and the iteration index.
      #
      # ### Usage
      # ```ruby
      # execute(:review_document) do
      #   chat(:review) do |my, document, idx|
      #     # The document from the collection is available as the second block parameter
      #     # The index in the collection is available as the third block parameter
      #     my.prompt = "Review document #{idx + 1}: #{document}. Provide feedback."
      #   end
      # end
      #
      # execute do
      #   map(:review_all, run: :review_document) do |my|
      #     my.items = ["proposal.md", "design.md", "implementation.md"]
      #   end
      # end
      # ```
      #
      # ### Input Options
      #
      # Set these attributes on the `my` input object within the block:
      #
      # - `items` (required) - The collection of items to iterate over (any enumerable)
      # - `initial_index` (optional) - The starting index for the first iteration (defaults to 0)
      #
      # You can also return a collection from the block, which will be used as `my.items` if not set explicitly.
      #
      # ### Flow Control
      #
      # Within the executed scope, call `break!` inside a cog's input block to terminate the map early.
      # Any iterations not yet started will not run (their outputs will be `nil`) and any iterations in progress
      # in parallel will be stopped (their outputs will also be `nil`)
      # The `outputs` block will still run for the iteration in which `break!` is called.
      #
      # Within the executed scope, call `next!` inside a cog's input block to terminate the current iteration and begin
      # next iteration immediately. The `outputs` block will still run for the current iteration, even when `next!` is called.
      #
      # ### Parallel Execution
      #
      # Configure parallel execution in the `config` block for this cog:
      # - `parallel(n)` - Execute up to `n` iterations concurrently
      # - `parallel!` - Execute all iterations concurrently with no limit
      # - `no_parallel!` - Execute serially, one at a time (default)
      #
      # ### See Also
      # - `call` - Execute a scope once with a single value
      # - `repeat` - Execute a scope multiple times in a loop
      # - `collect` - Collect all iteration results into an array
      # - `reduce` - Reduce iteration results to a single value
      #
      #: (?Symbol?, run: Symbol) {(Roast::DSL::SystemCogs::Map::Input, untyped, Integer) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def map(name = nil, run:, &block); end

      # Execute a scope multiple times in a loop
      #
      # The `repeat` cog executes a named execution scope (defined with `execute(:name)`) repeatedly
      # until `break!` is called. The output from each iteration becomes the input value for the
      # next iteration, allowing steps to be attempted repeatedly until a condition is met and for
      # the loop body behavior to evolve from one iteration to the next.
      #
      # ### Usage
      # ```ruby
      # execute(:improve_until_acceptable) do
      #   chat(:improve) do |my, content, idx|
      #     my.prompt = "Improve this content (iteration #{idx}): #{content}"
      #   end
      #
      #   chat(:evaluate) do |my|
      #     my.prompt = "Rate this content quality (1-10): #{chat!(:improve).response}"
      #   end
      #
      #   # The loop will continue indefinitely until break! is called in a cog's input block.
      #   ruby { |_, _, idx| break! if chat!(:evaluate).text.to_i >= 8 || idx >= 5 }
      #
      #   # The outputs block always runs, even on the iteration when break! is called.
      #   # The output of one iteration of the loop becomes the input to the next iteration.
      #   outputs! { chat!(:improve).response }
      # end
      #
      # execute do
      #   repeat(:refine, run: :improve_until_acceptable) do |my|
      #     my.value = "Initial draft content"
      #   end
      # end
      # ```
      #
      # ### Input Options
      #
      # Set these attributes on the `my` input object within the block:
      #
      # - `value` (required) - The initial value to pass to the first iteration
      # - `index` (optional) - The starting index for the first iteration (defaults to 0)
      #
      # You can also return a value from the block, which will be used as `my.value` if not set explicitly.
      #
      # ### Loop Control
      #
      # Within the executed scope, call `break!` inside a cog's input block to exit the loop. The
      # final output of the `repeat` cog is the output of the iteration where `break!` is called.
      # The `outputs` block always runs, even when `break!` is called (it acts as a finalizer).
      #
      # Within the executed scope, call `next!` inside a cog's input bloxk to exit the current iteration of the loop
      # and begin the next iteration. The `outputs` block always run on each iteration, even when `next!` is called.
      #
      # ### See Also
      # - `call` - Execute a scope once with a single value
      # - `map` - Execute a scope for each item in a collection
      # - `collect` - Access all iteration results (via `.results`)
      # - `reduce` - Reduce iteration results to a single value (via `.results`)
      #
      #: (?Symbol?, run: Symbol) {(Roast::DSL::SystemCogs::Repeat::Input, untyped, Integer) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def repeat(name = nil, run:, &block); end

      # Run a coding agent on the local machine
      #
      # The `agent` cog runs a coding agent on the local machine with access to local files,
      # tools, and MCP servers. It is designed for coding tasks and any work requiring local
      # filesystem access.
      #
      # The agent supports automatic session resumption across invocations.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   agent(:code_analyzer) { "Analyze the code in src/ and suggest improvements" }
      #
      #   # Resume from a previous session
      #   agent(:continue_analysis) do |my|
      #     my.prompt = "Now apply those improvements"
      #     my.session = agent!(:code_analyzer).session
      #   end
      # end
      # ```
      #
      # ### Input Options
      #
      # Set these attributes on the `my` input object within the block:
      #
      # - `prompt` (required) - The prompt to send to the agent
      # - `session` (optional) - Session identifier for conversation continuity
      #
      # You can also return a String from the block, which will be used as `my.prompt` if not set explicitly.
      #
      # ### Output
      #
      # Access these attributes on the output object:
      # - `response` - The agent's final text response
      # - `session` - Session identifier for resuming the conversation
      # - `stats` - Execution statistics (tokens, cost, etc.)
      # - `text` - The response text with whitespace stripped (same as `.response.strip`)
      # - `lines` - Array of lines from the response, each with whitespace stripped (same as `.response.lines.map(&:strip)`)
      # - `json` - Parse the response as JSON, returning nil if parsing fails
      # - `json!` - Parse the response as JSON, raising an error if parsing fails
      #
      # JSON parsing will aggressively and intelligently attempt to extract a JSON object from within surrounding
      # text produced by the agent, so you should not need to worry if the agent's response looks like "Here is the
      # JSON object you asked for: ..."
      #
      # ### See Also
      # - `chat` - Pure LLM interaction without local system access
      #
      #: (?Symbol?) {(Roast::DSL::Cogs::Agent::Input, untyped, Integer) [self: Roast::DSL::CogInputContext] -> (String | void)} -> void
      def agent(name = nil, &block); end

      # Perform pure LLM interaction
      #
      # The `chat` cog provides pure LLM interaction without local system access. While it
      # cannot access local files or run local tools, it can still perform complex reasoning
      # and access any provider-hosted tools and MCP servers according to the capabilities of the
      # model and the facilities that it may be equipped with by the LLM provider.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   chat(:analyzer) do |my|
      #     data = JSON.parse(File.read(target!))
      #     my.prompt = "Analyze this data and provide insights: #{data}"
      #   end
      #
      #   chat(:summarizer) do |my|
      #     my.prompt = "Summarize this: #{chat!(:analyzer).response}"
      #   end
      #
      #   # Resume a conversation by passing the session
      #   chat(:followup) do |my|
      #     my.prompt = "Can you elaborate on the second point?"
      #     my.session = chat!(:analyzer).session
      #   end
      # end
      # ```
      #
      # ### Input Options
      #
      # Set these attributes on the `my` input object within the block:
      #
      # - `prompt` (required) - The prompt to send to the language model
      # - `session` (optional) - Session object for conversation continuity
      #
      # You can also return a String from the block, which will be used as `my.prompt` if not set explicitly.
      #
      # ### Output
      #
      # Access these attributes on the output object:
      # - `response` - The LLM's text response
      # - `session` - Session object for resuming the conversation
      # - `text` - The response text with whitespace stripped (same as `.response.strip`)
      # - `lines` - Array of lines from the response, each with whitespace stripped (same as `.response.lines.map(&:strip)`)
      # - `json` - Parse the response as JSON, returning nil if parsing fails
      # - `json!` - Parse the response as JSON, raising an error if parsing fails
      #
      # JSON parsing will aggressively and intelligently attempt to extract a JSON object from within surrounding
      # text produced by the LLM, so you should not need to worry if the LLM's response looks like "Here is the
      # JSON object you asked for: ..."
      #
      # ### See Also
      # - `agent` - Run a coding agent with local filesystem access
      #
      #: (?Symbol?) {(Roast::DSL::Cogs::Chat::Input, untyped, Integer) [self: Roast::DSL::CogInputContext] -> (String | void)} -> void
      def chat(name = nil, &block); end

      # Execute a shell command
      #
      # The `cmd` cog executes shell commands and captures their output and exit status. It can
      # be configured to write its STDOUT and STDERR to the console as well.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   cmd(:list_files) do |my|
      #     my.command = "ls"
      #     my.args = ["-la", "/tmp"]
      #   end
      #
      #   # Simpler syntax: return command and args as array
      #   cmd(:git_status) { ["git", "status", "--short"] }
      #
      #   # Return a command string (can include pipes and redirects)
      #   cmd(:process_data) { "cat data.txt | grep 'pattern' | wc -l" }
      #
      #   # Complex shell command with pipe
      #   cmd(:find_errors) do
      #     "find . -name '*.log' | xargs grep 'ERROR' | head -n 10"
      #   end
      # end
      # ```
      #
      # ### Usage Style
      #
      # __Full command in a single string:__ Use this style when you want to take advantage of shell syntax like
      # globbing, or use pipes, output redirection, etc.
      #
      # __Command and array of arguments:__ Use this style when you do not need shell features, and you specifically
      # want to *avoid* having to escape values in command arguments.
      #
      # ### Input Options
      #
      # Set these attributes on the `my` input object within the block:
      #
      # - `command` (required) - The command to execute
      # - `args` (optional) - Array of arguments to pass to the command
      #
      # You can also return from the block:
      # - A String - used as the command (can include pipes, redirects, and other shell features)
      # - An Array - first element is the command, remaining elements are args
      #
      # ### Output
      #
      # Access these attributes on the output object:
      # - `out` - Standard output (STDOUT) from the command
      # - `err` - Standard error (STDERR) from the command
      # - `status` - The exit status of the command process
      # - `text` - The STDOUT text with whitespace stripped (same as `.out.strip`)
      # - `lines` - Array of lines from STDOUT, each with whitespace stripped (same as `.out.lines.map(&:strip)`)
      # - `json` - Parse STDOUT as JSON, returning nil if parsing fails
      # - `json!` - Parse STDOUT as JSON, raising an error if parsing fails
      #
      # ### See Also
      # - `ruby` - Evaluate Ruby code within the workflow context
      #
      #: (?Symbol?) {(Roast::DSL::Cogs::Cmd::Input, untyped, Integer) [self: Roast::DSL::CogInputContext] -> (String | Array[String] | void)} -> void
      def cmd(name = nil, &block); end

      # Evaluate Ruby code within the workflow context
      #
      # The `ruby` cog executes Ruby code in its input block. The return value of the block is
      # passed through unchanged as the cog's output. This allows you to perform transformations,
      # create data structures, or perform calculations that are easiest to accomplish with simple
      # Ruby code.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   ruby(:compute) { { sum: 1 + 2 + 3, product: 4 * 5 } }
      #
      #   ruby(:transform) do
      #     data = ruby!(:compute).value
      #     "Sum: #{data[:sum]}, Product: #{data[:product]}"
      #   end
      #
      #   # Access hash values directly on output via dynamic method dispatch
      #   ruby(:use_value) do |my|
      #     my.value = ruby!(:compute).sum  # Accesses hash[:sum]
      #   end
      #
      #   # Use for control flow
      #   ruby { |_, _, idx| break! if idx >= 3 }
      # end
      # ```
      #
      # ### Input Options
      #
      # Set these attributes on the `my` input object within the block:
      #
      # - `value` (required) - The value to pass through as output
      #
      # You can also return any Ruby object from the block, which will be used as `my.value` if
      # not set explicitly.
      #
      # ### Output
      #
      # The output provides convenient dynamic method dispatch:
      # - If the value responds to a method, it delegates to that method
      # - If the value is a Hash, methods correspond to hash keys
      # - Hash values that are Procs can be called directly as methods
      # - Use `[]` for direct hash key access
      # - Use `call()` to invoke Procs stored in the value
      # - Use `.value` to access the raw output value
      #
      # ### See Also
      # - `cmd` - Execute shell commands
      #
      #: (?Symbol?) {(Roast::DSL::Cogs::Ruby::Input, untyped, Integer) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def ruby(name = nil, &block); end
    end
  end
end
