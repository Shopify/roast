# typed: true
# frozen_string_literal: true

module Roast
  module Resources
    # Resource implementation for URLs
    class UrlResource < BaseResource
      def process
        # URLs don't need special processing, just return as is
        target
      end

      def exists?
        return false unless target

        begin
          uri = URI.parse(target)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == "https")

          # Just check the head to see if the resource exists
          response = http.request_head(uri.path&.empty? ? "/" : uri.path)

          # Consider 2xx and 3xx as success
          response.code.to_i < 400
        rescue Roast::Error => e
          # Log the error but don't crash
          Roast::Helpers::Logger.error("Error checking URL existence: #{e.message}")
          false
        end
      end

      def contents
        return unless target

        begin
          uri = URI.parse(target)
          Net::HTTP.get(uri)
        rescue Roast::Error => e
          # Log the error but don't crash
          Roast::Helpers::Logger.error("Error fetching URL contents: #{e.message}")
          nil
        end
      end

      def name
        if target
          URI.parse(target).host
        else
          "Unnamed URL"
        end
      rescue URI::InvalidURIError
        "Invalid URL"
      end

      def type
        :url
      end
    end
  end
end
