# frozen_string_literal: true

# Shared test cog infrastructure used across multiple test files.
module TestCogSupport
  class TestInput < Roast::Cog::Input
    attr_accessor :value

    def validate!
      raise InvalidInputError if value.nil? && !coerce_ran?
    end

    def coerce(input_return_value)
      super
      @value = input_return_value
    end
  end

  class TestOutput < Roast::Cog::Output
    attr_reader :value

    def initialize(value)
      super()
      @value = value
    end
  end

  class TestCog < Roast::Cog
    class Config < Roast::Cog::Config; end
    class Input < TestInput; end

    def execute(input)
      TestOutput.new(input.value)
    end
  end
end
