# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          class ToolUse
            #: Symbol
            attr_reader :name

            #: Hash[Symbol, untyped]
            attr_reader :input

            #: (name: Symbol, input: Hash[Symbol, untyped]) -> void
            def initialize(name:, input:)
              @name = name
              @input = input
            end

            #: () -> String
            def format
              format_method_name = "format_#{name}".to_sym
              return send(format_method_name) if respond_to?(format_method_name, true)

              format_unknown
            end

            # Truncate long formatted tool-use strings to keep terminal output to generally one line, accounting for logger prefixing.
            TRUNCATE_LIMIT = 45

            private

            # Truncates a string to at most TRUNCATE_LIMIT characters, appending
            # "..." when the string is cut. The returned string — including the
            # ellipsis — is guaranteed to be ≤ TRUNCATE_LIMIT characters.
            #
            # nil is coerced to "" (so callers needn't nil-check).
            # Strings at or below the limit are returned unchanged.
            #
            # Input:
            #   str (String?) – the string to truncate
            #
            # Output: the (possibly shortened) string
            #
            # Examples:
            #   truncate("ls -la")           # => "ls -la"
            #   truncate("a" * 50)           # => "aaa...aaa..." (45 chars)
            #   truncate(nil)                # => ""
            #
            #: (String?) -> String
            def truncate(str)
              s = str.to_s
              s.length > TRUNCATE_LIMIT ? "#{s[0...TRUNCATE_LIMIT - 3]}..." : s
            end

            # Formats a Bash tool-use line.
            #
            # Input fields:
            #   :command     (String) – shell command to execute      [required]
            #   :description (String) – human-readable label          [optional]
            #
            # Output: "BASH <command>", with " (<description>)" appended when
            # :description is present. :command is truncated to TRUNCATE_LIMIT chars.
            #
            # Examples:
            #   BASH ls -la (List directory contents)
            #   BASH ls -la
            #
            #: () -> String
            def format_bash
              command = truncate(input[:command])
              description = input[:description]
              label = command.empty? ? "BASH" : "BASH #{command}"
              description ? "#{label} (#{description})" : label
            end

            # Formats a Read tool-use line.
            #
            # Input fields:
            #   :file_path (String)  – absolute path to read         [required]
            #   :offset    (Integer) – 1-based first line            [optional]
            #   :limit     (Integer) – max number of lines to read   [optional]
            #
            # Output: "READ <file_path>", with a line range appended when :offset
            # and/or :limit is given:
            #   :limit set    → " (lines <start>–<end>)", start = :offset (default
            #                   1), end = start + :limit - 1
            #   :offset only  → " (from line <offset>)" (reads to end of file)
            # With neither, the bare "READ <file_path>".
            #
            # Examples:
            #   READ /app/models/user.rb (lines 30–80)
            #   READ /app/models/user.rb (from line 30)
            #   READ /app/models/user.rb
            #
            #: () -> String
            def format_read
              file_path, offset, limit = input.values_at(:file_path, :offset, :limit)
              details = if limit
                offset ||= 1
                "lines #{offset}–#{offset + limit - 1}"
              elsif offset
                "from line #{offset}"
              end
              label = file_path.to_s.empty? ? "READ" : "READ #{file_path}"
              details ? "#{label} (#{details})" : label
            end

            # Formats a Glob tool-use line.
            #
            # Input fields:
            #   :pattern (String) – glob pattern to match    [required]
            #   :path    (String) – directory to search in   [optional]
            #
            # Output: "GLOB <pattern>", with " (in <path>)" appended when :path
            # is present.
            #
            # Pattern is not truncated because glob expressions are typically short
            # and meaningful in their entirety, unlike shell commands.
            #
            # Examples:
            #   GLOB **/*.rb (in lib/roast)
            #   GLOB **/*.rb
            #
            #: () -> String
            def format_glob
              pattern, path = input.values_at(:pattern, :path)
              path ? "GLOB #{pattern} (in #{path})" : "GLOB #{pattern}"
            end

            # Formats a Grep tool-use line.
            #
            # Input fields:
            #   :pattern (String) – regex to search for          [required]
            #   :path    (String) – file or directory to search  [optional]
            #   :glob    (String) – filter files by glob         [optional]
            #   :type    (String) – filter files by type         [optional]
            #   :"-i"    (bool)   – case-insensitive match        [optional]
            #
            # Output: 'GREP "<pattern>"', then " <path>" when :path is present,
            # then " (<modifiers>)" when any of :glob, :type, :"-i" are set —
            # joined with " · " in that order. :pattern is truncated to
            # TRUNCATE_LIMIT chars; other grep options (such as :"-n") are not
            # displayed, as they shape grep's output rather than the search itself.
            #
            # Examples:
            #   GREP "def format" lib/roast (glob=*.rb · -i)
            #   GREP "TODO"
            #
            #: () -> String
            def format_grep
              pattern, path = input.values_at(:pattern, :path)
              base = "GREP \"#{truncate(pattern)}\""
              base = "#{base} #{path}" if path
              modifiers = [
                ("glob=#{input[:glob]}" if input[:glob]),
                ("type=#{input[:type]}" if input[:type]),
                ("-i" if input[:"-i"]),
              ].compact.join(" · ")
              modifiers.empty? ? base : "#{base} (#{modifiers})"
            end

            # Formats a Write tool-use line.
            #
            # Input fields:
            #   :file_path (String) – absolute path to write   [required]
            #   :content   (String) – full file contents       [required]
            #
            # Output: 'WRITE <file_path> "<preview>" (+<n> lines)', where
            # <preview> is the first line of :content (stripped, truncated to
            # TRUNCATE_LIMIT chars) and <n> is the total number of lines written
            # (singular " line" when <n> is 1). The count is always shown.
            #
            # Examples:
            #   WRITE /app/models/user.rb "class User < ApplicationRecord" (+10 lines)
            #   WRITE /config/app.yml "enabled: true" (+1 line)
            #
            #: () -> String
            def format_write
              file_path, content = input.values_at(:file_path, :content)
              lines = content.to_s.lines
              preview = truncate(lines.first.to_s.strip)
              count = lines.length
              line_label = count == 1 ? "line" : "lines"
              "WRITE #{file_path} \"#{preview}\" (+#{count} #{line_label})"
            end

            #: () -> String
            def format_unknown
              "UNKNOWN [#{name}] #{input.inspect}"
            end
          end
        end
      end
    end
  end
end
