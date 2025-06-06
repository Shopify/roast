# frozen_string_literal: true

require "test_helper"

module Roast
  module ValueObjects
    class ApiTokenTest < ActiveSupport::TestCase
      def test_initialization_with_valid_token
        token = ApiToken.new("valid-token-123")
        assert_equal("valid-token-123", token.value)
      end

      def test_initialization_with_nil
        token = ApiToken.new(nil)
        assert_nil(token.value)
        assert(token.blank?)
        refute(token.present?)
      end

      def test_initialization_with_empty_string_raises_error
        assert_raises(ApiToken::InvalidTokenError) do
          ApiToken.new("")
        end
      end

      def test_initialization_with_whitespace_only_raises_error
        assert_raises(ApiToken::InvalidTokenError) do
          ApiToken.new("   ")
        end
      end

      def test_present_and_blank_methods
        valid_token = ApiToken.new("token123")
        assert(valid_token.present?)
        refute(valid_token.blank?)

        nil_token = ApiToken.new(nil)
        refute(nil_token.present?)
        assert(nil_token.blank?)
      end

      def test_to_s_returns_value
        token = ApiToken.new("my-token")
        assert_equal("my-token", token.to_s)
      end

      def test_equality
        token1 = ApiToken.new("token123")
        token2 = ApiToken.new("token123")
        token3 = ApiToken.new("different")

        assert_equal(token1, token2)
        refute_equal(token1, token3)
        refute_equal(token1, "token123")
        refute_equal(token1, nil)
      end

      def test_nil_tokens_are_equal
        token1 = ApiToken.new(nil)
        token2 = ApiToken.new(nil)

        assert_equal(token1, token2)
      end

      def test_eql_method
        token1 = ApiToken.new("token123")
        token2 = ApiToken.new("token123")

        assert(token1.eql?(token2))
      end

      def test_hash_equality
        token1 = ApiToken.new("token123")
        token2 = ApiToken.new("token123")
        token3 = ApiToken.new("different")

        assert_equal(token1.hash, token2.hash)
        refute_equal(token1.hash, token3.hash)
      end

      def test_can_be_used_as_hash_key
        hash = {}
        token1 = ApiToken.new("token123")
        token2 = ApiToken.new("token123")

        hash[token1] = "value"
        assert_equal("value", hash[token2])
      end

      def test_frozen_after_initialization
        token = ApiToken.new("token123")
        assert(token.frozen?)
      end

      def test_coerces_non_string_to_string
        token = ApiToken.new(123)
        assert_equal("123", token.value)
      end
    end
  end
end
