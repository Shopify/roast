# typed: true
# frozen_string_literal: true

class Simple < Roast::DSL::Cog
  class Input < Roast::DSL::Cog::Input
    def validate!
      true
    end
  end

  #: (Input) -> void
  def execute(input)
    puts "I'm a cog!"
  end
end
