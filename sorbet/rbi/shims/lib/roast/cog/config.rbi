# typed: true
# frozen_string_literal: true

module Roast
  class Cog
    class Config
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
      # roast execute my_workflow.rb my_target_file.txt
      # ```
      #
      # ### Usage
      # ```ruby
      # config do
      #   chat do
      #     # Configure based on the single target
      #     temperature(target!.end_with?(".md") ? 0.7 : 0.2)
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
      # roast execute my_workflow.rb target_one.txt target_two.txt
      # ```
      # or using shell globs like this:
      # ```bash
      # roast execute my_workflow.rb target_*.txt
      # ```
      #
      # ### Usage
      # ```ruby
      # config do
      #   map do
      #     # Process targets in parallel when there are several
      #     parallel! if targets.length > 3
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
      # roast execute my_workflow.rb [TARGETS] -- retry force
      # ```
      #
      # ### Usage
      # ```ruby
      # config do
      #   chat do
      #     # Pick a cheaper model when invoked with the `fast` flag
      #     model(arg?(:fast) ? "gpt-5.4-nano" : "gpt-5")
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
      # roast execute my_workflow.rb [TARGETS] -- retry force
      # ```
      #
      # ### Usage
      # ```ruby
      # config do
      #   global do
      #     # Show full output whenever any flags were passed
      #     display! unless args.empty?
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
      # roast execute my_workflow.rb [TARGETS] -- name=Samantha project=Roast
      # ```
      #
      # ### Usage
      # ```ruby
      # config do
      #   chat do
      #     # Use a provided model override, or fall back to a default
      #     model(kwarg(:model) || "gpt-5")
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
      # roast execute my_workflow.rb [TARGETS] -- name=Samantha project=Roast
      # ```
      #
      # ### Usage
      # ```ruby
      # config do
      #   chat do
      #     # Require the 'model' keyword argument
      #     model(kwarg!(:model))
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
      # roast execute my_workflow.rb [TARGETS] -- name=Samantha project=Roast
      # ```
      #
      # ### Usage
      # ```ruby
      # config do
      #   chat do
      #     temperature(0.9) if kwarg?(:creative)
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
      # roast execute my_workflow.rb [TARGETS] -- name=Samantha project=Roast
      # ```
      #
      # ### Usage
      # ```ruby
      # config do
      #   chat do
      #     model(kwargs[:model] || "gpt-5")
      #     temperature(kwargs[:temperature]&.to_f || 0.3)
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
    end
  end
end
