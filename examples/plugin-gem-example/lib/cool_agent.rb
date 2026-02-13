# typed: true
# frozen_string_literal: true

class CoolAgent < Roast::Cogs::Agent::Provider
  class Output < Roast::Cogs::Agent::Output
    def stats
      Roast::Cogs::Agent::Stats.new
    end

    def response
      "I think lakes are cool"
    end

    def success
      true
    end
  end

  def invoke(input)
    return Output.new
  end
end
