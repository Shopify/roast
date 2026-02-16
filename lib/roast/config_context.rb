# typed: true
# frozen_string_literal: true

module Roast
  # Context in which the `config` blocks of a workflow definition are evaluated
  class ConfigContext
    #: (^(Symbol) -> bool) -> void
    def initialize(agent_provider_exists_proc)
      @agent_provider_exists_proc = agent_provider_exists_proc
    end

    #: (Symbol) -> bool
    def agent_provider_exists?(name)
      @agent_provider_exists_proc.call(name)
    end
  end
end
