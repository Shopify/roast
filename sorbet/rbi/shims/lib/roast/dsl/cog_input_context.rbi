# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class CogInputContext

      ########################################
      #             Workflow Methods
      ########################################

      # Get the single target value passed to the workflow
      #
      # Returns the target when exactly one target was provided to the workflow. Raises an
      # `ArgumentError` if the workflow was invoked with zero or multiple targets.
      #
      # Targets are file paths, URLs, or other identifiers passed to the workflow when it is
      # invoked. Use this method when your workflow expects exactly one target.
      #
      # ### Invocation
      # Invoke a workflow with a single target like this:
      # ```bash
      # roast execute --executor=dsl my_workflow.rb my_target_file.txt
      # ```
      #
      # ### Usage
      # ```ruby
      # execute do
      #   chat(:analyze) do |my|
      #     # Get the single target
      #     file_path = target!
      #     content = File.read(file_path)
      #     my.prompt = "Analyze this file: #{content}"
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `targets` - Get all targets as an array (works with any number of targets)
      #
      #: () -> String
      def target!; end

      # Get all targets passed to the workflow
      #
      # Returns an array of all targets provided to the workflow. Works with any number of targets
      # (zero, one, or many). Targets are file paths, URLs, or other identifiers passed when the
      # workflow is invoked.
      #
      # ### Invocation
      # Invoke a workflow with multiple targets like this:
      # ```bash
      # roast execute --executor=dsl my_workflow.rb target_one.txt target_two.txt
      # ```
      # or using shell globs like this:
      # ```bash
      # roast execute --executor=dsl my_workflow.rb target_*.txt
      # ```
      #
      # ### Usage
      # ```ruby
      # execute do
      #   map(:process_files, run: :analyze_file) do |my|
      #     # Get all targets to process
      #     my.items = targets
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `target!` - Get the single target (raises an error if there isn't exactly one)
      #
      #: () -> Array[String]
      def targets; end

      # Check if a flag argument was passed to the workflow
      #
      # Returns `true` if the specified flag argument symbol was provided when the workflow
      # was invoked, `false` otherwise.
      #
      # Flag arguments are symbolic flags passed to the workflow (e.g., `retry`, `force`)
      # that enable or modify behavior.
      #
      # ### Invocation
      # Invoke a workflow with flag arguments like this:
      # ```bash
      # roast execute --executor=dsl my_workflow.rb [TARGETS] -- retry force
      # ```
      #
      # ### Usage
      # ```ruby
      # execute do
      #   ruby do
      #     if arg?(:retry)
      #       puts "Retry mode enabled"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `args` - Get all flag arguments as an array
      # - `kwarg?` - Check for keyword arguments (key-value pairs)
      #
      #: (Symbol) -> bool
      def arg?(value); end

      # Get all flag arguments passed to the workflow
      #
      # Returns an array of all flag argument symbols provided when the workflow was invoked.
      # Flag arguments are symbolic flags (e.g., `retry`, `force`) that enable or modify
      # workflow behavior.
      #
      # ### Invocation
      # Invoke a workflow with flag arguments like this:
      # ```bash
      # roast execute --executor=dsl my_workflow.rb [TARGETS] -- retry force
      # ```
      #
      # ### Usage
      # ```ruby
      # execute do
      #   ruby do
      #     puts "Arguments: #{args.join(", ")}"
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `arg?` - Check if a specific flag argument was provided
      # - `kwargs` - Get all keyword arguments
      #
      #: () -> Array[Symbol]
      def args; end

      # Get a keyword argument value passed to the workflow
      #
      # Returns the string value for the specified keyword argument key, or `nil` if the key was
      # not provided. Keyword arguments are key-value pairs passed to the workflow for configuration.
      #
      # ### Invocation
      # Invoke a workflow with keyword arguments like this:
      # ```bash
      # roast execute --executor=dsl my_workflow.rb [TARGETS] -- name=Samantha project=Roast
      # ```
      #
      # ### Usage
      # ```ruby
      # execute do
      #   chat(:greet) do |my|
      #     # Get keyword argument with nil fallback
      #     name = kwarg(:name) || "World"
      #     my.prompt = "Say hello to #{name}"
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `kwarg!` - Get a keyword argument value (raises an error if not provided)
      # - `kwarg?` - Check if a keyword argument was provided
      # - `kwargs` - Get all keyword arguments as a hash
      #
      #: (Symbol) -> String?
      def kwarg(key); end

      # Get a required keyword argument value passed to the workflow
      #
      # Returns the string value for the specified keyword argument key. Raises an `ArgumentError`
      # if the key was not provided.
      #
      # Use this when your workflow requires a specific keyword argument to function correctly.
      #
      # ### Invocation
      # Invoke a workflow with keyword arguments like this:
      # ```bash
      # roast execute --executor=dsl my_workflow.rb [TARGETS] -- name=Samantha project=Roast
      # ```
      #
      # ### Usage
      # ```ruby
      # execute do
      #   chat(:greet) do |my|
      #     # Require the 'name' keyword argument
      #     name = kwarg!(:name)
      #     my.prompt = "Say hello to #{name}"
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `kwarg` - Get a keyword argument value (returns nil if not provided)
      # - `kwarg?` - Check if a keyword argument was provided
      # - `kwargs` - Get all keyword arguments as a hash
      #
      #: (Symbol) -> String
      def kwarg!(key); end

      # Check if a keyword argument was passed to the workflow
      #
      # Returns `true` if the specified keyword argument key was provided when the workflow was
      # invoked, `false` otherwise.
      #
      # ### Invocation
      # Invoke a workflow with keyword arguments like this:
      # ```bash
      # roast execute --executor=dsl my_workflow.rb [TARGETS] -- name=Samantha project=Roast
      # ```
      #
      # ### Usage
      # ```ruby
      # execute do
      #   ruby do
      #     if kwarg?(:name)
      #       puts "Name was provided: #{kwarg(:name)}"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `kwarg` - Get a keyword argument value (returns nil if not provided)
      # - `kwarg!` - Get a keyword argument value (raises an error if not provided)
      # - `kwargs` - Get all keyword arguments as a hash
      #
      #: (Symbol) -> bool
      def kwarg?(key); end

      # Get all keyword arguments passed to the workflow
      #
      # Returns a hash of all keyword argument key-value pairs provided when the workflow was invoked.
      # All keys are symbols and all values are strings.
      #
      # ### Invocation
      # Invoke a workflow with keyword arguments like this:
      # ```bash
      # roast execute --executor=dsl my_workflow.rb [TARGETS] -- name=Samantha project=Roast
      # ```
      #
      # ### Usage
      # ```ruby
      # execute do
      #   ruby do
      #     puts "Keyword arguments:"
      #     kwargs.each do |key, value|
      #       puts "  #{key}: #{value}"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `kwarg` - Get a single keyword argument value
      # - `kwarg!` - Get a required keyword argument value
      # - `kwarg?` - Check if a keyword argument was provided
      #
      #: () -> Hash[Symbol, String]
      def kwargs; end

      # Get the temporary directory for this workflow execution
      #
      # Returns a `Pathname` object representing a temporary directory that is unique to this
      # workflow execution. The directory is created automatically and will persist for the
      # duration of the workflow, then be automatically removed.
      #
      # Use this for storing intermediate files, caching data, or other temporary artifacts
      # that your workflow needs during execution.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   ruby do
      #     temp_file = tmpdir / "data.json"
      #     File.write(temp_file, JSON.dump({ status: "processing" }))
      #   end
      #
      #   cmd do |my|
      #     # Reference the temp directory in commands
      #     my.command = "ls"
      #     my.args = ["-la", tmpdir.to_s]
      #   end
      # end
      # ```
      #
      #: () -> Pathname
      def tmpdir; end

      ########################################
      #             System Cogs
      ########################################

      # Extract output from a single execution scope
      #
      # Retrieves output from the execution scope that was invoked by a `call` cog, or from a specific iteration
      # of the scope invoked by a `map` or `repeat` cog.
      #
      # When called without a block, returns the scope's final output directly (from its `outputs!` or `outputs` block).
      # When called with a block, executes the block in the context of the called scope, receiving the scope's final
      # output, input value, and index as arguments. Inside this block, you can access the output of cogs from the
      # specified scope, as opposed to the current scope.
      #
      # ### Usage
      # ```ruby
      # execute(:summarize_article) do
      #   chat(:summary) do |my, article_text|
      #     my.prompt = "Summarize this article: #{article_text}"
      #   end
      #
      #   outputs! { chat!(:summary).lines[0..5].join("\n) }
      # end
      #
      # execute do
      #   call(:process, run: :summarize_article) { "Long article text..." }
      #
      #   # Get the final output directly
      #   short_summary = from(call!(:process))
      #
      #   # Access other cog outputs from within the called scope
      #   full_response = from(call!(:process)) { chat!(:summary).response }
      #
      #   # Access cog outputs and final output together
      #   lines_reduced = from(call!(:process)) do |_, article_text|
      #     article_text.lines.length - chat!(:summary).lines.length
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `call!` - Invoke a named execution scope
      # - `collect` - Collect results from a `map` cog
      # - `reduce` - Reduce results from a `map` cog
      #
      #: [T] (Roast::DSL::SystemCogs::Call::Output) {(untyped, untyped, Integer) -> T} -> T
      #: (Roast::DSL::SystemCogs::Call::Output) -> untyped
      def from(call_cog_output, &block); end

      # Collect results from all `map` cog iterations into an array
      #
      # Retrieves output from the execution scopes that were invoked for each element in the iterable passed to a `map`,
      # or from each iteration of a `repeat` loop. When called without a block, returns an array of the final outputs
      # directly. When called with a block, executes the block in the context of each iteration's input context,
      # receiving the final output, the original input value (e.g., element from the iterable passed to `map`), and
      # the iteration index as arguments.
      #
      # Iterations that did not run (due to `break!` being called in a different iteration) are skipped.
      # The block __will not__ be called for iterations that did not run. The block __will__ be called for the
      # iteration in which `break!` was invoked.
      #
      # ### Usage
      # ```ruby
      # execute(:review_document) do
      #   agent(:review) do |my, document, idx|
      #     my.prompt = "Review document #{idx + 1}: #{document}"
      #   end
      #
      #   outputs! { agent!(:review).text }
      # end
      #
      # execute do
      #   map(:review_all, run: :review_document) { ["doc1.md", "doc2.md", "doc3.md"] }
      #
      #   # Get all final outputs directly
      #   reviews = collect(map!(:review_all))
      #
      #   # Access other cog outputs from within each iteration
      #   review_length = collect(map!(:review_all)) { chat!(:review).response.length }
      #
      #   # Access final output along with the original item and index and all intermediate cog outputs
      #   results = collect(map!(:review_all)) do |review, document, index|
      #     { document:, review:, index:, lines: agent!(:review).lines.length }
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `map` - Execute a scope for each item in a collection
      # - `reduce` - Reduce iteration results to a single value
      # - `from` - Extract output from the execution scope corresponding to a single iteration
      #
      #: [T] (Roast::DSL::SystemCogs::Map::Output) {(untyped, untyped, Integer) -> T} -> Array[T]
      #: (Roast::DSL::SystemCogs::Map::Output) -> Array[untyped]
      def collect(map_cog_output, &block); end

      # Reduce results from all `map` or `repeat` cog iterations to a single value
      #
      # Retrieves output from the execution scopes that were invoked for each element in the iterable passed to a `map`,
      # or from each iteration of a `repeat` loop, and combines them into a single accumulator value. The block
      # executes in the context of each iteration's input context, receiving the current accumulator value, the final
      # output, the original input value (e.g., element from the iterable passed to `map`), and the iteration index
      # as arguments. The block should return the new accumulator value.
      #
      # If the block returns `nil`, the accumulator will __not__ be updated (preserving any
      # previous non-nil value). This prevents accidental overwrites with `nil` values.
      #
      # Iterations that did not run (due to `break!` being called in a different iteration) are skipped.
      # The block __will not__ be called for iterations that did not run. The block __will__ be called for the
      # iteration in which `break!` was invoked.
      #
      # ### Usage
      # ```ruby
      # execute(:calculate_score) do
      #   chat(:score) { |_, item| "Rate this item (1-10): #{item} -- Answer as a JSON: `{ rating: N }`" }
      #
      #   outputs! { chat!(:score).json![:rating] }
      # end
      #
      # execute do
      #   map(:score_items, run: :calculate_score) { ["item1", "item2", "item3"] }
      #
      #   # Sum all outputs
      #   total = reduce(map!(:score_items), 0) do |sum, output|
      #     sum + output
      #   end
      #
      #   # Build a hash from outputs
      #   results = reduce(map!(:score_items), {}) do |hash, output, item|
      #     hash.merge(item => output)
      #   end
      #
      #   # Access intermediate cog outputs and combine with conditional accumulation
      #   high_scores = reduce(map!(:score_items), []) do |acc, output, item, index|
      #     # Can access cog outputs from within each iteration's scope
      #     output >= 8 ? acc + [{ item:, score: output, details: chat!(:score).response }] : acc
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `map` - Execute a scope for each item in a collection
      # - `repeat` - Execute a scope multiple times in a loop
      # - `collect` - Collect all iteration results into an array
      # - `from` - Extract output from the execution scope corresponding to a single iteration
      #
      #: [A] (Roast::DSL::SystemCogs::Map::Output, ?NilClass) {(A?, untyped, untyped, Integer) -> A} -> A?
      #: [A] (Roast::DSL::SystemCogs::Map::Output, ?A) {(A, untyped, untyped, Integer) -> A} -> A
      def reduce(map_cog_output, initial_value = nil, &block); end

      # Access the output of a `call` cog
      #
      # Returns the output of the `call` cog with the given name if it ran and completed successfully,
      # or `nil` otherwise. This method will __not__ raise an exception if the cog did not run,
      # was skipped, failed, or was stopped. This method __will__ raise an exception if the named cog does not exist.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `nil` immediately.
      #
      # NOTE: The return value of `call(:cog_name)` is an opaque object, from which you must use `from`
      # to extract values.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   call(:optional_step, run: :process_data) { "input data" }
      #
      #   ruby do
      #     result = call(:optional_step)
      #     if result
      #       puts "Step ran: #{from(result)}"
      #     else
      #       puts "Step did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `call!` - Access the output (raises an exception if the cog did not run successfully)
      # - `call?` - Check if the cog ran successfully (returns a boolean)
      # - `from` - Extract the final output from the called scope
      #
      #: (Symbol) -> Roast::DSL::SystemCogs::Call::Output?
      def call(name); end

      # Access the output of a `call` cog
      #
      # Returns the output of the `call` cog with the given name. Raises an exception if the cog
      # did not run, was skipped, failed, or was stopped. This is the recommended method for accessing cog outputs
      # when you expect the cog to always have run successfully.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `nil` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   call(:process, run: :analyze_data) { "input data" }
      #
      #   # Access the output with confidence it ran
      #   result = from(call!(:process))
      # end
      # ```
      #
      # #### See Also
      # - `call` - Access the output (returns nil if the cog did not run successfully)
      # - `call?` - Check if the cog ran successfully (returns a boolean)
      # - `from` - Extract the final output from the called scope
      #
      #: (Symbol) -> Roast::DSL::SystemCogs::Call::Output
      def call!(name); end

      # Check if a `call` cog ran successfully
      #
      # Returns `true` if the `call` cog with the given name ran and completed successfully,
      # `false` otherwise. Use this to check whether a cog ran before attempting to access
      # its output.
      #
      # If `call?(:name)` returns `true`, then `call!(:name)` will not raise an exception.
      # The inverse is also true.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `false` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   call(:optional_step, run: :process_data) { "input data" }
      #
      #   ruby do
      #     if call?(:optional_step)
      #       result = from(call!(:optional_step))
      #       puts "Result: #{result}"
      #     else
      #       puts "Step did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `call` - Access the output (returns nil if the cog did not run successfully)
      # - `call!` - Access the output (raises an exception if the cog did not run successfully)
      #
      #: (Symbol) -> bool
      def call?(name); end

      # Access the output of a `map` cog
      #
      # Returns the output of the `map` cog with the given name if it ran and completed successfully,
      # or `nil` otherwise. This method will __not__ raise an exception if the cog did not run,
      # was skipped, failed or was stopped. This method __will__ raise an exception if the named cog does not exist.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `nil` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   map(:optional_map, run: :process_items) { ["item1", "item2"] }
      #
      #   ruby do
      #     result = map(:optional_map)
      #     if result
      #       items = collect(result)
      #       puts "Processed #{items.length} items"
      #     else
      #       puts "Map did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `map!` - Access the output (raises an exception if the cog did not run successfully)
      # - `map?` - Check if the cog ran successfully (returns a boolean)
      # - `collect` - Collect all iteration results into an array
      # - `reduce` - Reduce iteration results to a single value
      #
      #: (Symbol) -> Roast::DSL::SystemCogs::Map::Output?
      def map(name); end

      # Access the output of a `map` cog
      #
      # Returns the output of the `map` cog with the given name. Raises an exception if the cog
      # did not run, was skipped, failed or was stopped. This is the recommended method for accessing cog outputs
      # when you expect the cog to have run successfully.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `nil` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   map(:process_items, run: :analyze_item) { ["item1", "item2", "item3"] }
      #
      #   # Access all iteration results
      #   results = collect(map!(:process_items))
      #
      #   # Or reduce to a single value
      #   total = reduce(map!(:process_items), 0) { |sum, output| sum + output }
      # end
      # ```
      #
      # #### See Also
      # - `map` - Access the output (returns nil if the cog did not run successfully)
      # - `map?` - Check if the cog ran successfully (returns a boolean)
      # - `collect` - Collect all iteration results into an array
      # - `reduce` - Reduce iteration results to a single value
      #
      #: (Symbol) -> Roast::DSL::SystemCogs::Map::Output
      def map!(name); end

      # Check if a `map` cog ran successfully
      #
      # Returns `true` if the `map` cog with the given name ran and completed successfully,
      # `false` otherwise. Use this to check whether a cog ran before attempting to access
      # its output.
      #
      # If `map?(name)` returns `true`, then `map!(name)` will not raise an exception.
      # The inverse is also true.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `false` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   map(:optional_map, run: :process_items) { ["item1", "item2"] }
      #
      #   ruby do
      #     if map?(:optional_map)
      #       results = collect(map!(:optional_map))
      #       puts "Processed #{results.length} items"
      #     else
      #       puts "Map did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `map` - Access the output (returns nil if the cog did not run successfully)
      # - `map!` - Access the output (raises an exception if the cog did not run successfully)
      #
      #: (Symbol) -> bool
      def map?(name); end

      # Access the output of a `repeat` cog
      #
      # Returns the output of the `repeat` cog with the given name if it ran and completed successfully,
      # or `nil` otherwise. This method will __not__ raise an exception if the cog did not run,
      # was skipped, failed, or was stopped. This method __will__ raise an exception if the named cog does not exist.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `nil` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   repeat(:optional_loop, run: :improve_content) { "initial content" }
      #
      #   ruby do
      #     result = repeat(:optional_loop)
      #     if result
      #       final_value = result.value
      #       puts "Final result: #{final_value}"
      #     else
      #       puts "Loop did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `repeat!` - Access the output (raises an exception if the cog did not run successfully)
      # - `repeat?` - Check if the cog ran successfully (returns a boolean)
      # - `collect` - Collect all iteration results via `.results`
      # - `reduce` - Reduce iteration results to a single value via `.results`
      #
      #: (Symbol) -> Roast::DSL::SystemCogs::Repeat::Output?
      def repeat(name); end

      # Access the output of a `repeat` cog
      #
      # Returns the output of the `repeat` cog with the given name. Raises an exception if the cog
      # did not run, was skipped, failed, or was stopped. This is the recommended method for accessing cog outputs
      # when you expect the cog to have run successfully.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `nil` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   repeat(:refine, run: :improve_content) { "initial content" }
      #
      #   # Access the final value from the last iteration
      #   final_result = repeat!(:refine).value
      #
      #   # Or collect all iteration results
      #   all_iterations = collect(repeat!(:refine).results)
      # end
      # ```
      #
      # #### See Also
      # - `repeat` - Access the output (returns nil if the cog did not run successfully)
      # - `repeat?` - Check if the cog ran successfully (returns a boolean)
      # - `collect` - Collect all iteration results via `.results`
      # - `reduce` - Reduce iteration results to a single value via `.results`
      #
      #: (Symbol) -> Roast::DSL::SystemCogs::Repeat::Output
      def repeat!(name); end

      # Check if a `repeat` cog ran successfully
      #
      # Returns `true` if the `repeat` cog with the given name ran and completed successfully,
      # `false` otherwise. Use this to check whether a cog ran before attempting to access
      # its output.
      #
      # If `repeat?(name)` returns `true`, then `repeat!(name)` will not raise an exception.
      # The inverse is also true.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `nil` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   repeat(:optional_loop, run: :improve_content) { "initial content" }
      #
      #   ruby do
      #     if repeat?(:optional_loop)
      #       result = repeat!(:optional_loop).value
      #       puts "Final result: #{result}"
      #     else
      #       puts "Loop did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `repeat` - Access the output (returns nil if the cog did not run successfully)
      # - `repeat!` - Access the output (raises an exception if the cog did not run successfully)
      #
      #: (Symbol) -> bool
      def repeat?(name); end

      ########################################
      #            Standard Cogs
      ########################################

      # Access the output of an `agent` cog
      #
      # Returns the output of the `agent` cog with the given name if it ran and completed successfully,
      # or `nil` otherwise. This method will __not__ raise an exception if the cog did not run,
      # was skipped, failed, or was stopped. This method __will__ raise an exception if the named cog does not exist.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `false` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   agent(:optional_agent) { "Analyze the code in src/" }
      #
      #   ruby do
      #     result = agent(:optional_agent)
      #     if result
      #       puts "Agent response: #{result.response}"
      #     else
      #       puts "Agent did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `agent!` - Access the output (raises an exception if the cog did not run successfully)
      # - `agent?` - Check if the cog ran successfully (returns a boolean)
      #
      #: (Symbol) -> Roast::DSL::Cogs::Agent::Output?
      def agent(name); end

      # Access the output of an `agent` cog
      #
      # Returns the output of the `agent` cog with the given name. Raises an exception if the cog
      # did not run, was skipped, failed, or was stopped. This is the recommended method for accessing cog outputs
      # when you expect the cog to have run successfully.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `nil` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   agent(:code_analyzer) { "Analyze the code in src/ and suggest improvements" }
      #
      #   chat(:summarize) do |my|
      #     # Use the agent's response in subsequent steps
      #     my.prompt = "Summarize these suggestions: #{agent!(:code_analyzer).response}"
      #   end
      #
      #   # Resume from a previous agent session
      #   agent(:continue) do |my|
      #     my.prompt = "Now apply those improvements"
      #     my.session = agent!(:code_analyzer).session
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `agent` - Access the output (returns nil if the cog did not run successfully)
      # - `agent?` - Check if the cog ran successfully (returns a boolean)
      #
      #: (Symbol) -> Roast::DSL::Cogs::Agent::Output
      def agent!(name); end

      # Check if an `agent` cog ran successfully
      #
      # Returns `true` if the `agent` cog with the given name ran and completed successfully,
      # `false` otherwise. Use this to check whether a cog ran before attempting to access
      # its output.
      #
      # If `agent?(name)` returns `true`, then `agent!(name)` will not raise an exception.
      # The inverse is also true.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `false` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   agent(:optional_agent) { "Analyze the code in src/" }
      #
      #   ruby do
      #     if agent?(:optional_agent)
      #       response = agent!(:optional_agent).response
      #       puts "Agent completed: #{response}"
      #     else
      #       puts "Agent did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `agent` - Access the output (returns nil if the cog did not run successfully)
      # - `agent!` - Access the output (raises an exception if the cog did not run successfully)
      #
      #: (Symbol) -> bool
      def agent?(name); end

      # Access the output of a `chat` cog
      #
      # Returns the output of the `chat` cog with the given name if it ran and completed successfully,
      # or `nil` otherwise. This method will __not__ raise an exception if the cog did not run,
      # was skipped, failed, or was stopped. This method __will__ raise an exception if the named cog does not exist.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `nil` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   chat(:optional_chat) { "Analyze this data..." }
      #
      #   ruby do
      #     result = chat(:optional_chat)
      #     if result
      #       puts "Chat response: #{result.response}"
      #     else
      #       puts "Chat did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `chat!` - Access the output (raises an exception if the cog did not run successfully)
      # - `chat?` - Check if the cog ran successfully (returns a boolean)
      #
      #: (Symbol) -> Roast::DSL::Cogs::Chat::Output?
      def chat(name); end

      # Access the output of a `chat` cog (raises an exception if it did not run successfully)
      #
      # Returns the output of the `chat` cog with the given name. Raises an exception if the cog
      # did not run, was skipped, failed, or was stopped. This is the recommended method for accessing cog outputs
      # when you expect the cog to have run successfully.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `nil` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   chat(:analyzer) do |my|
      #     data = JSON.parse(File.read("data.json"))
      #     my.prompt = "Analyze this data: #{data}"
      #   end
      #
      #   chat(:summarizer) do |my|
      #     # Use the previous chat's response
      #     my.prompt = "Summarize this analysis: #{chat!(:analyzer).response}"
      #   end
      #
      #   # Parse JSON responses
      #   ruby do
      #     insights = chat!(:analyzer).json!
      #     puts "Key insights: #{insights[:key_findings]}"
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `chat` - Access the output (returns nil if the cog did not run successfully)
      # - `chat?` - Check if the cog ran successfully (returns a boolean)
      #
      #: (Symbol) -> Roast::DSL::Cogs::Chat::Output
      def chat!(name); end

      # Check if a `chat` cog ran successfully
      #
      # Returns `true` if the `chat` cog with the given name ran and completed successfully,
      # `false` otherwise. Use this to check whether a cog ran before attempting to access
      # its output.
      #
      # If `chat?(name)` returns `true`, then `chat!(name)` will not raise an exception.
      # The inverse is also true.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `false` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   chat(:optional_chat) { "Analyze this data..." }
      #
      #   ruby do
      #     if chat?(:optional_chat)
      #       response = chat!(:optional_chat).response
      #       puts "Chat completed: #{response}"
      #     else
      #       puts "Chat did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `chat` - Access the output (returns nil if the cog did not run successfully)
      # - `chat!` - Access the output (raises an exception if the cog did not run successfully)
      #
      #: (Symbol) -> bool
      def chat?(name); end

      # Access the output of a `cmd` cog
      #
      # Returns the output of the `cmd` cog with the given name if it ran and completed successfully,
      # or `nil` otherwise. This method will __not__ raise an exception if the cog did not run,
      # was skipped, failed, or was stopped. This method __will__ raise an exception if the named cog does not exist.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `nil` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   cmd(:optional_cmd) { "ls -la" }
      #
      #   ruby do
      #     result = cmd(:optional_cmd)
      #     if result
      #       puts "Command output: #{result.out}"
      #     else
      #       puts "Command did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `cmd!` - Access the output (raises an exception if the cog did not run successfully)
      # - `cmd?` - Check if the cog ran successfully (returns a boolean)
      #
      #: (Symbol) -> Roast::DSL::Cogs::Cmd::Output?
      def cmd(name); end

      # Access the output of a `cmd` cog
      #
      # Returns the output of the `cmd` cog with the given name. Raises an exception if the cog
      # did not run, was skipped, failed, or was stopped. This is the recommended method for accessing cog outputs
      # when you expect the cog to have run successfully.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `false` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   cmd(:git_status) { ["git", "status", "--short"] }
      #
      #   chat(:analyze_changes) do |my|
      #     # Use command output in subsequent steps
      #     my.prompt = "Analyze these git changes: #{cmd!(:git_status).out}"
      #   end
      #
      #   # Parse JSON output from commands
      #   cmd(:get_data) { "curl -s https://api.example.com/data" }
      #   ruby do
      #     data = cmd!(:get_data).json!
      #     puts "Fetched #{data[:items].length} items"
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `cmd` - Access the output (returns nil if the cog did not run successfully)
      # - `cmd?` - Check if the cog ran successfully (returns a boolean)
      #
      #: (Symbol) -> Roast::DSL::Cogs::Cmd::Output
      def cmd!(name); end

      # Check if a `cmd` cog ran successfully
      #
      # Returns `true` if the `cmd` cog with the given name ran and completed successfully,
      # `false` otherwise. Use this to check whether a cog ran before attempting to access
      # its output.
      #
      # If `cmd?(name)` returns `true`, then `cmd!(name)` will not raise an exception.
      # The inverse is also true.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `false` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   cmd(:optional_cmd) { "ls -la" }
      #
      #   ruby do
      #     if cmd?(:optional_cmd)
      #       output = cmd!(:optional_cmd).out
      #       puts "Command completed: #{output}"
      #     else
      #       puts "Command did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `cmd` - Access the output (returns nil if the cog did not run successfully)
      # - `cmd!` - Access the output (raises an exception if the cog did not run successfully)
      #
      #: (Symbol) -> bool
      def cmd?(name); end

      # Access the output of a `ruby` cog
      #
      # Returns the output of the `ruby` cog with the given name if it ran and completed successfully,
      # or `nil` otherwise. This method will __not__ raise an exception if the cog did not run,
      # was skipped, failed, or was stopped. This method __will__ raise an exception if the named cog does not exist.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `nil` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   ruby(:optional_ruby) { { sum: 1 + 2 + 3, product: 4 * 5 } }
      #
      #   ruby do
      #     result = ruby(:optional_ruby)
      #     if result
      #       puts "Computed: #{result.value}"
      #     else
      #       puts "Ruby cog did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `ruby!` - Access the output (raises an exception if the cog did not run successfully)
      # - `ruby?` - Check if the cog ran successfully (returns a boolean)
      #
      #: (Symbol) -> untyped?
      def ruby(name); end

      # Access the output of a `ruby` cog
      #
      # Returns the output of the `ruby` cog with the given name. Raises an exception if the cog
      # did not run, was skipped, failed, or was stopped. This is the recommended method for accessing cog outputs
      # when you expect the cog to have run successfully.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `nil` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   ruby(:compute) do
      #     {
      #       sum: 1 + 2 + 3,
      #       product: 4 * 5,
      #       divide: proc { |a, b| a / b }
      #     }
      #   end
      #
      #   ruby(:transform) do
      #     # Access hash values via dynamic method dispatch
      #     sum = ruby!(:compute).sum
      #     product = ruby!(:compute).product
      #     quotient = ruby!(:compute).divide(15, 3)
      #     "Sum: #{sum}, Product: #{product}, Quotient: #{quotient}"
      #   end
      #
      #   # Access the raw value
      #   ruby do
      #     data = ruby!(:compute).value
      #     puts "Computed: #{data.inspect}"
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `ruby` - Access the output (returns nil if the cog did not run successfully)
      # - `ruby?` - Check if the cog ran successfully (returns a boolean)
      #
      #: (Symbol) -> untyped
      def ruby!(name); end

      # Check if a `ruby` cog ran successfully
      #
      # Returns `true` if the `ruby` cog with the given name ran and completed successfully,
      # `false` otherwise. Use this to check whether a cog ran before attempting to access
      # its output.
      #
      # If `ruby?(name)` returns `true`, then `ruby!(name)` will not raise an exception.
      # The inverse is also true.
      #
      # If the cog is currently running (if configured to run asynchronously), this method will block
      # and wait for the cog to complete before returning. If the cog has not yet started, this method
      # will return `false` immediately.
      #
      # ### Usage
      # ```ruby
      # execute do
      #   ruby(:optional_ruby) { { sum: 1 + 2 + 3, product: 4 * 5 } }
      #
      #   ruby do
      #     if ruby?(:optional_ruby)
      #       result = ruby!(:optional_ruby).value
      #       puts "Ruby completed: #{result.inspect}"
      #     else
      #       puts "Ruby cog did not run or did not complete successfully"
      #     end
      #   end
      # end
      # ```
      #
      # #### See Also
      # - `ruby` - Access the output (returns nil if the cog did not run successfully)
      # - `ruby!` - Access the output (raises an exception if the cog did not run successfully)
      #
      #: (Symbol) -> bool
      def ruby?(name); end
    end
  end
end
