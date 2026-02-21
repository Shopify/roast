# typed: true
# frozen_string_literal: true

module Roast
  class WorkflowContext
    #: WorkflowParams
    attr_reader :params

    #: String
    attr_reader :tmpdir

    #: Pathname
    attr_reader :workflow_dir

    #: (params: WorkflowParams, tmpdir: String, workflow_dir: Pathname) -> void
    def initialize(params:, tmpdir:, workflow_dir:)
      @params = params
      @tmpdir = tmpdir
      @workflow_dir = workflow_dir
      @provider_registry = ProviderRegistry.new
    end

    def prepare!
      @provider_registry.prepare!
    end

    #: (singleton(Cogs::Agent::Provider), ?Symbol?) -> void
    def register_agent_provider(provider_class, name = nil)
      @provider_registry.register(provider_class, name)
    end

    #: (Symbol, Cogs::Agent::Config) -> Cogs::Agent::Provider
    def agent_provider(name, config)
      @provider_registry.fetch(name).new(config)
    end

    #: (Symbol) -> bool
    def agent_provider_exists?(name)
      @provider_registry.exists?(name)
    end
  end
end
