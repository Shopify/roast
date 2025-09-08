# typed: true
# frozen_string_literal: true

module Roast
  module Resources
    # Resource implementation for API endpoints using Fetch API-style format
    class ApiResource < BaseResource
      def process
        # For API resources, the target might be a JSON configuration or endpoint URL
        target
      end

      def config
        return @config if defined?(@config)

        @config = if target.is_a?(String) && target.match?(/^\s*{/)
          begin
            JSON.parse(target)
          rescue JSON::ParserError
            nil
          end
        end
      end

      def api_url
        if config && config["url"]
          config["url"]
        else
          # Assume direct URL
          target
        end
      end

      def options
        return {} unless config

        config["options"] || {}
      end

      def http_method
        method_name = (options["method"] || "GET").upcase
        case method_name
        when "GET" then Net::HTTP::Get
        when "POST" then Net::HTTP::Post
        when "PUT" then Net::HTTP::Put
        when "DELETE" then Net::HTTP::Delete
        when "PATCH" then Net::HTTP::Patch
        when "HEAD" then Net::HTTP::Head
        else Net::HTTP::Get
        end
      end

      def exists?
        return false unless target

        uri = URI.parse(api_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")

        # Use HEAD request to check existence
        request = Net::HTTP::Head.new(uri.path&.empty? ? "/" : uri.path)

        # Add headers if present in options
        if options["headers"].is_a?(Hash)
          options["headers"].each do |key, value|
            # Process any environment variables in header values
            processed_value = process_env_vars(value.to_s)
            request[key] = processed_value
          end
        end

        # Make the request
        response = http.request(request)

        # Consider 2xx and 3xx as success
        response.code.to_i < 400
      rescue Roast::Error => e
        # Log the error but don't crash
        Roast::Helpers::Logger.error("Error checking API existence: #{e.message}")
        false
      end

      def contents
        return unless target

        # If it's a configuration, return a prepared request object
        if config
          JSON.pretty_generate({
            "url" => api_url,
            "method" => (options["method"] || "GET").upcase,
            "headers" => options["headers"] || {},
            "body" => options["body"],
          })
        else
          # Assume it's a direct API URL, do a simple GET
          begin
            uri = URI.parse(target)
            Net::HTTP.get(uri)
          rescue Roast::Error => e
            # Log the error but don't crash
            Roast::Helpers::Logger.error("Error fetching API contents: #{e.message}")
            nil
          end
        end
      end

      def name
        if target
          if config && config["url"]
            "API #{config["url"]} (#{(options["method"] || "GET").upcase})"
          else
            "API #{target}"
          end
        else
          "Unnamed API"
        end
      end

      def type
        :api
      end

      private

      # Replace environment variables in the format ${VAR_NAME}
      def process_env_vars(text)
        text.gsub(/\${([^}]+)}/) do |_match|
          var_name = ::Regexp.last_match(1)&.strip
          ENV.fetch(var_name, "${#{var_name}}") unless var_name.nil?
        end
      end
    end
  end
end
