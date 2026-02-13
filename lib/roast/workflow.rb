# typed: true
# frozen_string_literal: true

module Roast
  class Workflow
    class WorkflowError < Roast::Error; end
    class WorkflowNotPreparedError < WorkflowError; end
    class WorkflowAlreadyPreparedError < WorkflowError; end
    class WorkflowAlreadyStartedError < WorkflowError; end
    class InvalidLoadableReference < WorkflowError; end

    class << self
      #: (String | Pathname, WorkflowParams) -> void
      def from_file(workflow_path, params)
        Dir.mktmpdir("roast-") do |tmpdir|
          workflow_dir = Pathname.new(workflow_path).dirname
          workflow_context = WorkflowContext.new(params: params, tmpdir: tmpdir, workflow_dir: workflow_dir)
          workflow = new(workflow_path, workflow_context)
          workflow.prepare!
          workflow.start!
        end
      end
    end

    #: (String | Pathname, WorkflowContext) -> void
    def initialize(workflow_path, workflow_context)
      @workflow_path = Pathname.new(workflow_path) #: Pathname
      @workflow_context = workflow_context #: WorkflowContext
      @workflow_definition = File.read(workflow_path) #: String
      @cog_registry = Cog::Registry.new #: Cog::Registry
      @config_procs = [] #: Array[^() -> void]
      @execution_procs = { nil: [] } #: Hash[Symbol?, Array[^() -> void]]
      @config_manager = nil #: ConfigManager?
      @execution_manager = nil #: ExecutionManager?
    end

    #: () -> void
    def prepare!
      raise WorkflowAlreadyPreparedError if preparing? || prepared?

      @preparing = true
      extract_dsl_procs!
      @config_manager = ConfigManager.new(@cog_registry, @config_procs)
      @config_manager.not_nil!.prepare!
      # TODO: probably we should just not pass the params as the top-level scope value anymore
      @execution_manager = ExecutionManager.new(@cog_registry, @config_manager.not_nil!, @execution_procs, @workflow_context, scope_value: @workflow_context.params)
      @execution_manager.not_nil!.prepare!

      @prepared = true
    end

    #: () -> void
    def start!
      raise WorkflowNotPreparedError unless @config_manager.present? && @execution_manager.present?
      raise WorkflowAlreadyStartedError if started? || completed?

      @started = true
      begin
        @execution_manager.run!
      rescue ControlFlow::Break
        # treat `break!` like `next!` in the top-level executor scope
        # TODO: maybe do something with the message passed to break!
      end
      @completed = true
    end

    #: () -> bool
    def preparing?
      @preparing ||= false
    end

    #: () -> bool
    def prepared?
      @prepared ||= false
    end

    #: () -> bool
    def started?
      @started ||= false
    end

    #: () -> bool
    def completed?
      @completed ||= false
    end

    #: { () [self: Roast::ConfigContext] -> void } -> void
    def config(&block)
      @config_procs << block
    end

    #: (?Symbol?) { () [self: Roast::ExecutionContext] -> void } -> void
    def execute(scope = nil, &block)
      (@execution_procs[scope] ||= []) << block
    end

    def use(*loadables, from: nil)
      if from
        # Load gem - no special requires, gem must handle everything
        require from
      else
        # Load from local path
        loadables.each do |cog_name|
          require @workflow_path.realdirpath.dirname.join("cogs/#{cog_name}").to_s
        end
      end
      loadables.each do |name|
        class_name_string = name.camelize
        raise InvalidLoadableReference, "#{name} class not found" unless Object.const_defined?(class_name_string)

        class_name = class_name_string.constantize # rubocop:disable Sorbet/ConstantsFromStrings
        if class_name < Roast::Cog
          @cog_registry.use(class_name)
        elsif class_name < Roast::Cogs::Agent::Provider
          @provider_registry.register(class_name)
        else
          raise InvalidLoadableReference, "#{class_name_string} is not a subclass of a usable Roast primitive (cog, provider)."
        end
      end
    end

    private

    # Evaluate the top-level workflow definition
    # This collects the procs passed to `config` and `execute` calls in the workflow definition,
    # but does not evaluate any of them individually yet.
    #: () -> void
    def extract_dsl_procs!
      instance_eval(@workflow_definition, @workflow_path.realpath.to_s, 1)
    end

    # Register the built in agent providers.
    def add_providers!
      @provider_registry.register(Roast::Cogs::Agent::Providers::Claude, :claude)
    end
  end
end
