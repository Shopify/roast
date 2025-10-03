# typed: false
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      class Config
        attr_reader :values

        def initialize(initial = {})
          @values = initial
        end

        def merge(config_object)
          self.class.new(values.merge(config_object.values))
        end

        def configure!(&block)
          instance_exec(&block)
        end
      end
    end
  end
end
