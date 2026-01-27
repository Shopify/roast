# frozen_string_literal: true

require "test_helper"

module Roast
  class Cog
    class OutputTest < ActiveSupport::TestCase
      def setup
        @output = Output.new
      end

      test "raw_text raises NotImplementedError" do
        assert_raises(NotImplementedError) do
          @output.send(:raw_text)
        end
      end

      test "subclass can override raw_text" do
        subclass = Class.new(Output) do
          def raw_text
            "custom output"
          end
        end

        output = subclass.new

        assert_equal "custom output", output.send(:raw_text)
      end

      # Test Output subclasses with JSON parsing capabilities
      test "output with JSON support parses valid JSON" do
        json_output = Class.new(Output) do
          include Output::WithJson

          def raw_text
            '{"key": "value"}'
          end
        end.new

        assert_equal({ key: "value" }, json_output.json!)
      end

      test "output with JSON support raises error on invalid JSON with json!" do
        json_output = Class.new(Output) do
          include Output::WithJson

          def raw_text
            "not json"
          end
        end.new

        assert_raises(JSON::ParserError) { json_output.json! }
      end

      test "output with JSON support returns nil on invalid JSON with json" do
        json_output = Class.new(Output) do
          include Output::WithJson

          def raw_text
            "not json"
          end
        end.new

        assert_nil json_output.json
      end

      test "output with JSON support handles empty input" do
        json_output = Class.new(Output) do
          include Output::WithJson

          def raw_text
            nil
          end
        end.new

        assert_equal({}, json_output.json!)
      end

      test "output with JSON support extracts JSON from markdown code blocks" do
        json_output = Class.new(Output) do
          include Output::WithJson

          def raw_text
            "Here's some JSON:\n```json\n{\"key\": \"value\"}\n```"
          end
        end.new

        assert_equal({ key: "value" }, json_output.json!)
      end

      test "output with JSON support extracts JSON-like blocks from text" do
        json_output = Class.new(Output) do
          include Output::WithJson

          def raw_text
            "Some text before\n{\"key\": \"value\"}\nSome text after"
          end
        end.new

        assert_equal({ key: "value" }, json_output.json!)
      end

      # Test Output subclasses with number parsing capabilities
      test "output with number support parses floats" do
        number_output = Class.new(Output) do
          include Output::WithNumber

          def raw_text
            "42.5"
          end
        end.new

        assert_equal 42.5, number_output.float!
      end

      test "output with number support parses integers as floats" do
        number_output = Class.new(Output) do
          include Output::WithNumber

          def raw_text
            "42"
          end
        end.new

        assert_equal 42.0, number_output.float!
      end

      test "output with number support raises error on invalid number with float!" do
        number_output = Class.new(Output) do
          include Output::WithNumber

          def raw_text
            "not a number"
          end
        end.new

        assert_raises(ArgumentError) { number_output.float! }
      end

      test "output with number support returns nil on invalid number with float" do
        number_output = Class.new(Output) do
          include Output::WithNumber

          def raw_text
            "not a number"
          end
        end.new

        assert_nil number_output.float
      end

      test "output with number support parses and rounds to integers" do
        number_output = Class.new(Output) do
          include Output::WithNumber

          def raw_text
            "42.7"
          end
        end.new

        assert_equal 43, number_output.integer!
      end

      test "output with number support parses integer values" do
        number_output = Class.new(Output) do
          include Output::WithNumber

          def raw_text
            "42"
          end
        end.new

        assert_equal 42, number_output.integer!
      end

      test "output with number support returns nil on invalid integer" do
        number_output = Class.new(Output) do
          include Output::WithNumber

          def raw_text
            "not a number"
          end
        end.new

        assert_nil number_output.integer
      end

      test "output with number support handles numbers with thousand separators" do
        number_output = Class.new(Output) do
          include Output::WithNumber

          def raw_text
            "1,234.56"
          end
        end.new

        assert_equal 1234.56, number_output.float!
      end

      test "output with number support handles currency symbols" do
        number_output = Class.new(Output) do
          include Output::WithNumber

          def raw_text
            "$42.50"
          end
        end.new

        assert_equal 42.50, number_output.float!
      end

      # Test Output subclasses with text formatting capabilities
      test "output with text support returns stripped text" do
        text_output = Class.new(Output) do
          include Output::WithText

          def raw_text
            "  hello world  \n"
          end
        end.new

        assert_equal "hello world", text_output.text
      end

      test "output with text support returns lines as array" do
        text_output = Class.new(Output) do
          include Output::WithText

          def raw_text
            "  line1  \n  line2  \n  line3  "
          end
        end.new

        assert_equal ["line1", "line2", "line3"], text_output.lines
      end

      test "output with text support handles empty text" do
        text_output = Class.new(Output) do
          include Output::WithText

          def raw_text
            "   \n   "
          end
        end.new

        assert_equal "", text_output.text
      end
    end
  end
end
