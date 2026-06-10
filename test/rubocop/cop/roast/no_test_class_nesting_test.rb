# frozen_string_literal: true

require "test_helper"
require "rubocop"
require_relative "../../../../internal/rubocop/cop/roast/no_test_class_nesting"

module RuboCop
  module Cop
    module Roast
      class NoTestClassNestingTest < ActiveSupport::TestCase
        def setup
          config = RuboCop::Config.new("Roast/NoTestClassNesting" => { "Enabled" => true })
          @cop = NoTestClassNesting.new(config)
        end

        # === Offense cases: direct nesting ===

        test "flags test class nested directly inside reopened class with superclass" do
          offenses = investigate(<<~RUBY)
            class Agent < Cog
              class ConfigTest < ActiveSupport::TestCase
              end
            end
          RUBY

          assert_equal 1, offenses.size
          assert_includes offenses.first.message, "reopened class `Agent`"
        end

        test "flags test class nested inside reopened class without superclass" do
          offenses = investigate(<<~RUBY)
            class Cog
              class ConfigTest < ActiveSupport::TestCase
              end
            end
          RUBY

          assert_equal 1, offenses.size
          assert_includes offenses.first.message, "reopened class `Cog`"
        end

        test "flags when multiple test classes are nested inside one wrapper" do
          offenses = investigate(<<~RUBY)
            class Agent < Cog
              class ConfigTest < ActiveSupport::TestCase
              end

              class InputTest < ActiveSupport::TestCase
              end
            end
          RUBY

          # One offense for the wrapper class
          assert_equal 1, offenses.size
        end

        test "flags Minitest::Test as a test base class" do
          offenses = investigate(<<~RUBY)
            class Agent < Cog
              class ConfigTest < Minitest::Test
              end
            end
          RUBY

          assert_equal 1, offenses.size
        end

        # === Offense cases: nested modules ===

        test "flags module nested inside reopened class" do
          offenses = investigate(<<~RUBY)
            class Agent < Cog
              module Providers
              end
            end
          RUBY

          assert_equal 1, offenses.size
          assert_includes offenses.first.message, "reopened class `Agent`"
        end

        test "flags non-test class nested inside reopened class" do
          offenses = investigate(<<~RUBY)
            class Agent < Cog
              class Config
                def initialize; end
              end
            end
          RUBY

          assert_equal 1, offenses.size
          assert_includes offenses.first.message, "reopened class `Agent`"
        end

        # === Offense cases: deep nesting ===

        test "flags deeply nested module inside reopened class" do
          offenses = investigate(<<~RUBY)
            class Agent < Cog
              module Providers
                class Claude::MessageTest < ActiveSupport::TestCase
                end
              end
            end
          RUBY

          # Agent is flagged because it contains nested module Providers
          assert_equal 1, offenses.size
          assert_includes offenses.first.message, "reopened class `Agent`"
        end

        test "flags reopened class with deeply nested class chain" do
          offenses = investigate(<<~RUBY)
            class Agent < Cog
              module Providers
                class Claude < Provider
                  class MessageTest < ActiveSupport::TestCase
                  end
                end
              end
            end
          RUBY

          # Agent is flagged (contains module Providers)
          # Claude is also flagged (non-test class containing MessageTest)
          assert_equal 2, offenses.size
          parent_names = offenses.map { |o| o.message[/`(\w+)`/, 1] }
          assert_includes parent_names, "Agent"
          assert_includes parent_names, "Claude"
        end

        test "flags wrapper class inside modules" do
          offenses = investigate(<<~RUBY)
            module Roast
              module Cogs
                class Agent < Cog
                  class ConfigTest < ActiveSupport::TestCase
                  end
                end
              end
            end
          RUBY

          assert_equal 1, offenses.size
        end

        test "offense highlights class keyword and name" do
          offenses = investigate(<<~RUBY)
            class Agent < Cog
              module Providers
              end
            end
          RUBY

          assert_equal 1, offenses.first.line
          assert_equal 0, offenses.first.column
        end

        # === No-offense cases: :: scoping ===

        test "allows test class with :: scoping" do
          offenses = investigate(<<~RUBY)
            class Agent::ConfigTest < ActiveSupport::TestCase
            end
          RUBY

          assert_empty offenses
        end

        test "allows test class with :: scoping inside modules" do
          offenses = investigate(<<~RUBY)
            module Roast
              module Cogs
                class Agent::ConfigTest < ActiveSupport::TestCase
                end
              end
            end
          RUBY

          assert_empty offenses
        end

        test "allows :: scoped module with test class inside" do
          offenses = investigate(<<~RUBY)
            module Roast
              module Cogs
                module Agent::Providers
                  class Claude::MessageTest < ActiveSupport::TestCase
                  end
                end
              end
            end
          RUBY

          assert_empty offenses
        end

        test "allows deeply :: scoped module" do
          offenses = investigate(<<~RUBY)
            module Roast
              module Cogs
                module Agent::Providers::Claude::Messages
                  class TextMessageTest < ActiveSupport::TestCase
                  end
                end
              end
            end
          RUBY

          assert_empty offenses
        end

        # === No-offense cases: helpers inside test classes ===

        test "allows helper classes nested inside test classes" do
          offenses = investigate(<<~RUBY)
            class Agent::OutputTest < ActiveSupport::TestCase
              class FakeAdapter
                def call; end
              end
            end
          RUBY

          assert_empty offenses
        end

        test "allows helper subclass of production class inside test class" do
          offenses = investigate(<<~RUBY)
            class ConfigManagerTest < ActiveSupport::TestCase
              class TestCogConfig < Cog::Config
                field :timeout, 30
              end

              class TestCog < Cog
                class Config < TestCogConfig; end

                def execute(_input)
                  raise NotImplementedError
                end
              end
            end
          RUBY

          assert_empty offenses
        end

        test "allows Struct inside test class" do
          offenses = investigate(<<~RUBY)
            class Cmd::OutputTest < ActiveSupport::TestCase
              ProcessStatus = Struct.new(:exitstatus, :success)
            end
          RUBY

          assert_empty offenses
        end

        # === No-offense cases: other ===

        test "allows multiple test classes at module level" do
          offenses = investigate(<<~RUBY)
            module Roast
              module Cogs
                class Cmd::ConfigTest < ActiveSupport::TestCase
                end

                class Cmd::InputTest < ActiveSupport::TestCase
                end
              end
            end
          RUBY

          assert_empty offenses
        end

        test "allows single test class without wrapper" do
          offenses = investigate(<<~RUBY)
            class SimpleTest < ActiveSupport::TestCase
            end
          RUBY

          assert_empty offenses
        end

        test "allows empty reopened class (no nested definitions)" do
          offenses = investigate(<<~RUBY)
            class Agent < Cog
              def some_method; end
            end
          RUBY

          assert_empty offenses
        end

        private

        def investigate(source_code)
          source = RuboCop::ProcessedSource.new(source_code, RUBY_VERSION.to_f)
          commissioner = RuboCop::Cop::Commissioner.new([@cop])
          result = commissioner.investigate(source)
          result.offenses
        end
      end
    end
  end
end
