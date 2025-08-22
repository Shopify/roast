# typed: true
# frozen_string_literal: true

require "optparse"

module Roast
  class Command < CLI::Kit::BaseCommand
    Options = T.type_alias { T::Hash[T.untyped, T.untyped] }

    def initialize
      super()
    end

    protected

    def handle_error(error, message = nil)
      if message
        CLI::UI.puts("{{red:#{message}}}", to: $stderr)
      end
      raise CLI::Kit::Abort, error.message
    end

    def configure_options(command_name, parser, options)
      # Override this method to add options
      parser.on("-h", "--help") do
        puts self.class.help
        raise CLI::Kit::Abort
      end
    end

    def option_parser(command_name)
      options = {}
      parser = OptionParser.new do |p|
        p.set_program_name("roast #{Array(command_name).join(" ")}")
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
        puts self.class.help
        raise CLI::Kit::Abort
      end
    end
  end
end
