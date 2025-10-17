# typed: true
# frozen_string_literal: true

class Local < Roast::DSL::Cog
  class Input < Roast::DSL::Cog::Input
    def validate!
      true
    end
  end

  #: (Input) -> void
  def execute(input)
    puts "I'm a workflow-specific cog!"
  end
end
