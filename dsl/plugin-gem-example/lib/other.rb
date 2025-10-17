# typed: true
# frozen_string_literal: true

module MyCogNamespace
  class Other < Roast::DSL::Cog
    class Input < Roast::DSL::Cog::Input
      def validate!
        true
      end
    end

    #: (Input) -> void
    def execute(input)
      puts "I'm a different cog!"
    end
  end
end
