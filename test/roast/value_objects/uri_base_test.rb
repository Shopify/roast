# frozen_string_literal: true

require "test_helper"

module Roast
  module ValueObjects
    class UriBaseTest < ActiveSupport::TestCase
      def test_initialization_with_valid_uri_base
        uri_base = UriBase.new("https://api.example.com")
        assert_equal("https://api.example.com", uri_base.value)
      end

      def test_initialization_with_nil
        uri_base = UriBase.new(nil)
        assert_nil(uri_base.value)
        assert(uri_base.blank?)
        refute(uri_base.present?)
      end

      def test_initialization_with_empty_string_raises_error
        assert_raises(UriBase::InvalidUriBaseError) do
          UriBase.new("")
        end
      end

      def test_initialization_with_whitespace_only_raises_error
        assert_raises(UriBase::InvalidUriBaseError) do
          UriBase.new("   ")
        end
      end

      def test_present_and_blank_methods
        valid_uri_base = UriBase.new("https://api.example.com")
        assert(valid_uri_base.present?)
        refute(valid_uri_base.blank?)

        nil_uri_base = UriBase.new(nil)
        refute(nil_uri_base.present?)
        assert(nil_uri_base.blank?)
      end

      def test_to_s_returns_value
        uri_base = UriBase.new("https://api.example.com")
        assert_equal("https://api.example.com", uri_base.to_s)
      end

      def test_equality
        uri_base1 = UriBase.new("https://api.example.com")
        uri_base2 = UriBase.new("https://api.example.com")
        uri_base3 = UriBase.new("https://api.different.com")

        assert_equal(uri_base1, uri_base2)
        refute_equal(uri_base1, uri_base3)
        refute_equal(uri_base1, "https://api.example.com")
        refute_equal(uri_base1, nil)
      end

      def test_nil_uri_bases_are_equal
        uri_base1 = UriBase.new(nil)
        uri_base2 = UriBase.new(nil)

        assert_equal(uri_base1, uri_base2)
      end

      def test_eql_method
        uri_base1 = UriBase.new("https://api.example.com")
        uri_base2 = UriBase.new("https://api.example.com")

        assert(uri_base1.eql?(uri_base2))
      end

      def test_hash_equality
        uri_base1 = UriBase.new("https://api.example.com")
        uri_base2 = UriBase.new("https://api.example.com")
        uri_base3 = UriBase.new("https://api.different.com")

        assert_equal(uri_base1.hash, uri_base2.hash)
        refute_equal(uri_base1.hash, uri_base3.hash)
      end

      def test_can_be_used_as_hash_key
        hash = {}
        uri_base1 = UriBase.new("https://api.example.com")
        uri_base2 = UriBase.new("https://api.example.com")

        hash[uri_base1] = "value"
        assert_equal("value", hash[uri_base2])
      end

      def test_frozen_after_initialization
        uri_base = UriBase.new("https://api.example.com")
        assert(uri_base.frozen?)
      end

      def test_coerces_non_string_to_string
        uri_base = UriBase.new(123)
        assert_equal("123", uri_base.value)
      end
    end
  end
end
