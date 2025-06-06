# frozen_string_literal: true

module Roast
  module Workflow
    # Handles resource resolution and target processing
    # Extracts file/resource handling logic from Configuration
    class ResourceResolver
      class << self
        # Process the target and create appropriate resource object
        # @param target [String, nil] The target from configuration or options
        # @param context_path [String] The directory containing the workflow file
        # @return [Roast::Resources::BaseResource] The resolved resource object
        def resolve(target, context_path)
          return Roast::Resources::NoneResource.new(nil) unless has_target?(target)

          processed_target = process_target(target, context_path)
          Roast::Resources.for(processed_target)
        end

        # Process target through shell command expansion and glob pattern matching
        # @param target [String] The raw target string
        # @param context_path [String] The directory containing the workflow file
        # @return [String] The processed target
        def process_target(target, context_path)
          # Process shell command first
          processed = process_shell_command(target)

          # If it's a glob pattern, return the full paths of the files it matches
          if processed.include?("*")
            matched_files = Dir.glob(processed)
            # If no files match, return the pattern itself
            return processed if matched_files.empty?

            return matched_files.map { |file| File.expand_path(file) }.join("\n")
          end

          # For tests, if the command was already processed as a shell command and is simple,
          # don't expand the path to avoid breaking existing tests
          return processed if target != processed && !processed.include?("/")

          # Don't expand URLs
          return processed if processed.match?(%r{^https?://})

          # assumed to be a direct file path
          File.expand_path(processed)
        end

        # Process shell commands in $(command) or legacy % format
        # @param command [String] The command string
        # @return [String] The command output or original string if not a shell command
        def process_shell_command(command)
          # If it's a bash command with the $(command) syntax
          if command =~ /^\$\((.*)\)$/
            return Open3.capture2e({}, ::Regexp.last_match(1)).first.strip
          end

          # Legacy % prefix for backward compatibility
          if command.start_with?("% ")
            return Open3.capture2e({}, *command.split(" ")[1..-1]).first.strip
          end

          # Not a shell command, return as is
          command
        end

        private

        def has_target?(target)
          !target.nil? && !target.empty?
        end
      end
    end
  end
end
