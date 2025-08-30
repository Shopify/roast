# typed: true
# frozen_string_literal: true

module Roast
  class RoastResolver < CLI::Kit::Resolver
    private

    def command_not_found(name)
      super
      puts "Run 'roast --help' for usage information"
    end
  end

  Resolver = RoastResolver.new(
    tool_name: "roast",
    command_registry: Commands::Registry,
  )
end
