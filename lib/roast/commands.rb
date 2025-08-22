# typed: true
# frozen_string_literal: true

module Roast
  module Commands
    autoload :Execute,  "roast/commands/execute"
    autoload :Resume,   "roast/commands/resume"
    autoload :Version,  "roast/commands/version"
    autoload :Init,     "roast/commands/init"
    autoload :List,     "roast/commands/list"
    autoload :Validate, "roast/commands/validate"
    autoload :Sessions, "roast/commands/sessions"
    autoload :Session,  "roast/commands/session"
    autoload :Diagram,  "roast/commands/diagram"

    # Simple contextual resolver for Roast
    module ContextualResolver
      extend CLI::Kit::CommandRegistry::ContextualResolver

      class << self
        def aliases
          {} # No aliases for now
        end

        def command_names
          [] # No contextual commands for now
        end

        def command_class(name)
          nil # No contextual commands for now
        end
      end
    end

    Registry = CLI::Kit::CommandRegistry.new(
      default: "execute",
      contextual_resolver: ContextualResolver,
    )

    class << self
      def register(name, klass)
        Registry.add(-> { klass }, name)
      end
    end

    register("execute", Execute)
    register("resume", Resume)
    register("version", Version)
    register("init", Init)
    register("list", List)
    register("validate", Validate)
    register("sessions", Sessions)
    register("session", Session)
    register("diagram", Diagram)
  end
end
