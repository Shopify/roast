# frozen_string_literal: true

module Roast
  module Helpers
    class PromptLoader
      class << self
        # Loads a sidecar prompt file for a given context (workflow or step) and target file
        #
        # @param context [Object] The workflow or step instance
        # @param target_file [String] The path to the target file
        # @return [String, nil] The processed prompt content, or nil if no prompt is found
        def load_prompt(context, target_file)
          new(context, target_file).load
        end
      end

      def initialize(context, target_file)
        @context = context
        @name = context.name
        @context_path = context.context_path
        @target_file = target_file
      end

      def load
        prompt_content = read_prompt_file(find_prompt_path)
        return unless prompt_content

        process_erb_if_needed(prompt_content)
      end

      private

      attr_reader :context, :name, :context_path, :target_file

      def read_prompt_file(path)
        if path && File.exist?(path)
          File.read(path)
        else
          $stderr.puts "Prompt file for #{name} not found: #{path}"
        end
      end

      def find_prompt_path
        find_specialized_prompt_path(name, extract_file_extensions)
      end

      def find_specialized_prompt_path(base_name, extensions)
        context_dir = File.expand_path(context_path)

        # Try each extension to find a specialized prompt
        extensions.each do |ext|
          path = File.join(context_dir, "#{base_name}.#{ext}.md")
          path = File.join(context_dir, "prompt.#{ext}.md") unless File.exist?(path)
          return path if File.exist?(path)
        end

        # Check for combined format patterns (like ts+tsx)
        glob_pattern = File.join(context_dir, "{#{base_name},prompt}.*+*.md")
        Dir.glob(glob_pattern).each do |combined_path|
          basename = File.basename(combined_path, ".md")
          combined_exts = basename.split(".", 2)[1].split("+")

          # Return the first matching combined format
          return combined_path if extensions.intersect?(combined_exts)
        end

        # Fall back to the general prompt
        general_path = File.join(context_dir, "#{base_name}.md")
        general_path = File.join(context_dir, "prompt.md") unless File.exist?(general_path)
        general_path if File.exist?(general_path)
      end

      def extract_file_extensions
        return [] if target_file.nil?

        file_basename = File.basename(target_file)

        if file_basename.end_with?(".md") && file_basename.count(".") > 1
          without_md = file_basename[0...-3] # Remove .md
          without_md.split(".", 2)[1]&.split("+") || []
        else
          ext = File.extname(target_file)[1..]
          ext&.empty? ? [] : [ext]
        end
      end

      def process_erb_if_needed(content)
        if content.include?("<%")
          begin
            ERB.new(content, trim_mode: "-").result(context.instance_eval { binding })
          rescue TypeError => e
            if e.message.include?("no implicit conversion of nil into String")
              # Try to find which variable is causing the issue
              variable_hint = detect_nil_variable(content)

              error_message = <<~ERROR
                This workflow requires a file or target to be specified.
                #{variable_hint}

                Usage: roast execute <workflow.yml> <file_or_pattern>

                Examples:
                  roast execute #{context.respond_to?(:configuration) && context.configuration&.workflow_path || "workflow.yml"} test/my_test.rb
                  roast execute #{context.respond_to?(:configuration) && context.configuration&.workflow_path || "workflow.yml"} "test/**/*_test.rb"
              ERROR
              raise error_message
            else
              raise e
            end
          rescue NoMethodError => e
            if e.message.include?("undefined method") && e.message.include?("for nil")
              variable_hint = detect_nil_variable(content)

              error_message = <<~ERROR
                Error processing prompt template: #{e.message}
                #{variable_hint}

                This may indicate that the workflow requires a file or target to be specified.

                Usage: roast execute <workflow.yml> <file_or_pattern>
              ERROR
              raise error_message
            else
              raise e
            end
          end
        else
          content
        end
      end

      def detect_nil_variable(content)
        if content.include?("workflow.file")
          "The prompt template references 'workflow.file' but no file was provided."
        elsif content.include?("<%= file %>")
          "The prompt template references 'file' but no file was provided."
        elsif content.match(/<%= .*?\.(\w+) %>/)
          "The prompt template is trying to access a property that doesn't exist."
        else
          "The prompt template contains an ERB expression that references a nil value."
        end
      end
    end
  end
end
