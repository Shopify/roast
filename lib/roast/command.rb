# typed: true
# frozen_string_literal: true

module Roast
  class Command < CLI::Kit::BaseCommand
    Options = T.type_alias { T::Hash[T.untyped, T.untyped] }

    def initialize
      super()
    end

    # @final
    #: (Array[String], String) -> void
    def call(args, name)
      # We only parse the help flag here, the rest is handled by the subclass
      _options = parse_options(args, name)
      invoke(args, name)
    end

    # @abstract
    #: (Array[String], String) -> void
    def invoke(args, name)
      raise NotImplementedError, "Subclass must implement invoke"
    end

    #: (String, OptionParser, Options) -> void
    def configure_options(command_name, parser, options)
      # Optional override
    end

    # Get help message - checks for instance method first, then class method
    def help_message
      raise NotImplementedError, "Command must implement help_message"
    end

    def help_options(command_name, parser, options)
      parser.on("-h", "--help") do
        puts help_message
        raise CLI::Kit::Abort
      end
    end

    def option_parser(command_name)
      options = {}
      parser = OptionParser.new do |p|
        p.set_program_name("roast #{Array(command_name).join(" ")}")
        help_options(command_name, p, options)
        configure_options(command_name, p, options)
      end
      [parser, options]
    end

    def parse_options(args, command_name)
      parser, options = option_parser(command_name)
      begin
        parser.parse!(args)
        options
      rescue StandardError => e
        CLI::UI.puts("{{red:#{e}}}", to: $stderr)
        puts "\n"
        puts help_message
        raise Roast::Abort
      end
    end

    def handle_error(error, message = nil)
      if message
        CLI::UI.puts("{{red:#{message}}}", to: $stderr)
      end
      raise Roast::Abort, error.message
    end
  end
end
