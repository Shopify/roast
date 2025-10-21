# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ConfigContext
      #: (?Symbol?) {() [self: Roast::DSL::Cog::Config] -> void} -> void
      def call(name = nil, &block); end

      #: (?Symbol?) {() [self: Roast::DSL::Cog::Config] -> void} -> void
      def map(name = nil, &block); end

      # Configure the `cmd` cog
      #
      # ### Usage
      # - `cmd { &blk }` - Apply configuration to all instances of the `cmd` cog.
      # - `cmd(:name) { &blk }` - Apply configuration to the instance of the `cmd` cog named `:name`
      # - `cmd(/regexp/) { &blk }` - Apply configuration to any instance of the `cmd` cog whose name matches `/regexp/`
      #
      # ---
      #
      # ### Available Options
      #
      # Apply configuration within the block passed to `cmd`.
      #
      # These methods are available to apply configuration options to the `cmd` cog:
      # - `print_all!` – Configure the cog to write both STDOUT and STDERR to the console
      #   - alias `display!`
      # - `print_none!` -  Configure the cog to write __no output__ to the console, neither STDOUT nor STDERR
      #   - alias `no_display!`
      # - `print_stdout!` - Configure the cog to write STDOUT to the console
      # - `no_print_stdout!` - Configure the cog __not__ to write STDOUT to the console
      # - `print_stderr!` - Configure the cog to write STDERR to the console
      # - `no_print_stderr!` - Configure the cog __not__ to write STDERR to the console
      #
      # ---
      #
      #: (?(Symbol | Regexp)?) {() [self: Roast::DSL::Cogs::Cmd::Config] -> void} -> void
      def cmd(name_or_pattern = nil, &block); end

      #: (?Symbol?) {() [self: Roast::DSL::Cogs::Chat::Config] -> void} -> void
      def chat(name = nil, &block); end
    end
  end
end
