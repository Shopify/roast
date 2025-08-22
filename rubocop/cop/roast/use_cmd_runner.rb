# typed: false
# frozen_string_literal: true

module RuboCop
  module Cop
    module Roast
      # This cop suggests using CmdRunner instead of other command execution methods
      #
      # @example
      #   # bad
      #   `ls -la`
      #   %x(ls -la)
      #   system("ls -la")
      #   Open3.capture3("ls -la")
      #   spawn("ls -la")
      #   exec("ls -la")
      #
      #   # good
      #   CmdRunner.capture3("ls -la")
      #   CmdRunner.capture2e("ls -la")
      class UseCmdRunner < RuboCop::Cop::Base
        MSG = "Use `CmdRunner` instead of `%<method>s` for command execution to ensure proper process tracking and cleanup"

        # Pattern for backtick commands
        def_node_matcher :backtick_command?, <<~PATTERN
          (xstr ...)
        PATTERN

        # Pattern for %x() commands
        def_node_matcher :percent_x_command?, <<~PATTERN
          (xstr ...)
        PATTERN

        # Pattern for system() calls
        def_node_matcher :system_call?, <<~PATTERN
          (send nil? :system ...)
        PATTERN

        # Pattern for spawn() calls
        def_node_matcher :spawn_call?, <<~PATTERN
          (send nil? :spawn ...)
        PATTERN

        # Pattern for exec() calls
        def_node_matcher :exec_call?, <<~PATTERN
          (send nil? :exec ...)
        PATTERN

        # Pattern for Open3 methods
        def_node_matcher :open3_call?, <<~PATTERN
          (send (const nil? :Open3) {:capture2 :capture2e :capture3 :popen2 :popen2e :popen3} ...)
        PATTERN

        # Pattern for Process.spawn
        def_node_matcher :process_spawn?, <<~PATTERN
          (send (const nil? :Process) :spawn ...)
        PATTERN

        # Pattern for Kernel methods
        def_node_matcher :kernel_system?, <<~PATTERN
          (send (const nil? :Kernel) {:system :spawn :exec} ...)
        PATTERN

        # Pattern for IO.popen
        def_node_matcher :io_popen?, <<~PATTERN
          (send (const nil? :IO) :popen ...)
        PATTERN

        def on_xstr(node)
          add_offense(node, message: format(MSG, method: "backticks"))
        end

        def on_send(node)
          if system_call?(node) || kernel_system?(node)
            method_name = node.method_name
            add_offense(node, message: format(MSG, method: method_name))
          elsif spawn_call?(node)
            add_offense(node, message: format(MSG, method: "spawn"))
          elsif exec_call?(node)
            add_offense(node, message: format(MSG, method: "exec"))
          elsif open3_call?(node)
            method_name = "Open3.#{node.method_name}"
            add_offense(node, message: format(MSG, method: method_name))
          elsif process_spawn?(node)
            add_offense(node, message: format(MSG, method: "Process.spawn"))
          elsif io_popen?(node)
            add_offense(node, message: format(MSG, method: "IO.popen"))
          end
        end
      end
    end
  end
end
