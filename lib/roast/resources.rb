# frozen_string_literal: true

module Roast
  # The Resources module contains classes for handling different types of resources
  # that workflows can operate on. Each resource type implements a common interface.
  module Resources
    extend self

    # Create the appropriate resource based on the target
    # @param target [String] The target specified in the workflow
    # @return [BaseResource] A resource object of the appropriate type
    def for(target)
      type = detect_type(target)

      case type
      when :file
        FileResource.new(target)
      when :directory
        DirectoryResource.new(target)
      when :url
        UrlResource.new(target)
      when :api
        ApiResource.new(target)
      when :command
        CommandResource.new(target)
      when :none
        NoneResource.new(target)
      else
        BaseResource.new(target) # Default to base resource
      end
    end

    # Determines the resource type from the target
    # @param target [String] The target specified in the workflow
    # @return [Symbol] :file, :directory, :url, :api, or :none
    def detect_type(target)
      return :none if target.nil? || target.strip.empty?

      # Check for command syntax $(...)
      if target.match?(/^\$\(.*\)$/)
        return :command
      end

      # Check for URLs
      if target.start_with?("http://", "https://", "ftp://")
        return :url
      end

      # Try to parse as URI to detect other URL schemes
      begin
        uri = URI.parse(target)
        return :url if uri.scheme && uri.host
      rescue URI::InvalidURIError
        # Not a URL, continue with other checks
      end

      # Check for directory
      if Dir.exist?(target)
        return :directory
      end

      # Check for glob patterns (containing * or ?)
      if target.include?("*") || target.include?("?")
        matches = Dir.glob(target)
        return :none if matches.empty?
        # If the glob matches only directories, treat as directory type
        return :directory if matches.all? { |path| Dir.exist?(path) }

        # Otherwise treat as file type (could be mixed or all files)
        return :file
      end

      # Check for file
      if File.exist?(target)
        return :file
      end

      # Check for API configuration in Fetch API style format
      begin
        potential_config = JSON.parse(target)
        if potential_config.is_a?(Hash) && potential_config.key?("url") && potential_config.key?("options")
          return :api
        end
      rescue JSON::ParserError
        # Not a JSON string, continue with other checks
      end

      # Default to file for anything else
      :file
    end
  end
end
