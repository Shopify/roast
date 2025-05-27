# frozen_string_literal: true

module Roast
  module Workflow
    class DotAccessHash
      def initialize(hash)
        @hash = hash || {}
      end

      def [](key)
        value = @hash[key.to_sym] || @hash[key.to_s]
        value.is_a?(Hash) ? DotAccessHash.new(value) : value
      end

      def []=(key, value)
        @hash[key.to_sym] = value
      end

      def method_missing(method_name, *args, &block)
        method_str = method_name.to_s

        # Handle boolean predicate methods (ending with ?)
        if method_str.end_with?("?")
          key = method_str.chomp("?")
          # Always return false for non-existent keys with ? methods
          return false unless has_key?(key) # rubocop:disable Style/PreferredHashMethods

          !!self[key]
        # Handle setter methods (ending with =)
        elsif method_str.end_with?("=")
          key = method_str.chomp("=")
          self[key] = args.first
        # Handle bang methods (ending with !) - should raise
        elsif method_str.end_with?("!")
          super
        # Handle regular getter methods
        elsif args.empty? && block.nil?
          # Return nil for non-existent keys (like a hash would)
          self[method_str]
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        method_str = method_name.to_s

        if method_str.end_with?("!")
          false # Don't respond to bang methods
        elsif method_str.end_with?("?")
          true  # Always respond to predicate methods
        elsif method_str.end_with?("=")
          true  # Always respond to setter methods
        else
          true  # Always respond to getter methods (they return nil if missing)
        end
      end

      def to_h
        @hash
      end

      def keys
        @hash.keys
      end

      def empty?
        @hash.empty?
      end

      def each(&block)
        @hash.each(&block)
      end

      def to_s
        @hash.to_s
      end

      def inspect
        @hash.inspect
      end

      def to_json(*args)
        @hash.to_json(*args)
      end

      private

      def has_key?(key_name)
        @hash.key?(key_name.to_sym) || @hash.key?(key_name.to_s)
      end
    end
  end
end
