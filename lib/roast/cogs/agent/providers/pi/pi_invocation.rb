# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          class PiInvocation
            class PiInvocationError < Roast::Error; end

            class PiNotStartedError < PiInvocationError; end

            class PiAlreadyStartedError < PiInvocationError; end

            class PiNotCompletedError < PiInvocationError; end

            class PiFailedError < PiInvocationError; end

            class Context
              def initialize
                @tool_calls = {} #: Hash[String, Messages::ToolCallMessage]
              end

              #: (String?) -> Messages::ToolCallMessage?
              def tool_call(tool_call_id)
                @tool_calls[tool_call_id] if tool_call_id
              end

              #: (Messages::ToolCallMessage) -> void
              def add_tool_call(tool_call_message)
                id = tool_call_message.id
                @tool_calls[id] = tool_call_message if id
              end
            end

            class Result
              #: String
              attr_accessor :response

              #: bool
              attr_accessor :success

              #: String?
              attr_accessor :session

              #: Stats?
              attr_accessor :stats

              def initialize
                @response = ""
                @success = false
              end
            end

            #: (Agent::Config, Agent::Input) -> void
            def initialize(config, input)
              @base_command = config.valid_command #: (String | Array[String])?
              @model = config.valid_model #: String?
              @append_system_prompt = config.valid_append_system_prompt #: String?
              @replace_system_prompt = config.valid_replace_system_prompt #: String?
              @working_directory = config.valid_working_directory #: Pathname?
              @prompt = input.valid_prompt! #: String
              @session = input.session #: String?
              @context = Context.new #: Context
              @result = Result.new #: Result
              @raw_dump_file = config.valid_dump_raw_agent_messages_to_path #: Pathname?
              @show_progress = config.show_progress? #: bool
              @num_turns = 0 #: Integer
              @total_cost = 0.0 #: Float
              @model_usage_accumulator = {} #: Hash[String, Hash[Symbol, Numeric]]
              @current_text_block = +"" #: String
              @start_time_ms = nil #: Integer?
            end

            #: () -> void
            def run!
              raise PiAlreadyStartedError if started?

              @started = true
              @start_time_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).to_i
              _stdout, stderr, status = CommandRunner.execute(
                command_line,
                working_directory: @working_directory,
                stdin_content: @prompt,
                stdout_handler: lambda { |line| handle_stdout(line) },
              )
              @end_time_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).to_i #: Integer?

              if status.success?
                @completed = true
                @result.success = true
                finalize_stats!
              else
                @failed = true
                @result.success = false
                @result.response += "\n" unless @result.response.blank? || @result.response.ends_with?("\n")
                @result.response += stderr
              end
            end

            #: () -> bool
            def started?
              @started ||= false
            end

            #: () -> bool
            def running?
              started? && !completed? && !failed?
            end

            #: () -> bool
            def completed?
              @completed ||= false
            end

            #: () -> bool
            def failed?
              @failed ||= false
            end

            #: () -> Result
            def result
              raise PiNotStartedError unless started?
              raise PiFailedError, @result.response if failed?
              raise PiNotCompletedError, @result.response unless completed?

              @result
            end

            private

            #: (String) -> void
            def handle_stdout(line)
              line = line.strip
              return if line.empty?

              if @raw_dump_file
                @raw_dump_file.dirname.mkpath
                File.write(@raw_dump_file.to_s, "#{line}\n", mode: "a")
              end

              begin
                data = JSON.parse(line, symbolize_names: true)
              rescue JSON::ParserError
                return
              end

              handle_message(data)
            end

            #: (Hash[Symbol, untyped]) -> void
            def handle_message(data)
              type = data[:type]&.to_sym

              case type
              when :session
                handle_session(data)
              when :turn_start
                @num_turns += 1
              when :turn_end
                # turn_end contains the final assistant message and tool results for this turn
              when :message_update
                handle_message_update(data)
              when :message_end
                handle_message_end(data)
              when :tool_execution_start
                handle_tool_execution_start(data)
              when :tool_execution_end
                handle_tool_execution_end(data)
              when :agent_end
                handle_agent_end(data)
              when :agent_start, :message_start, :tool_execution_update
                # These are informational; no action needed
              end
            end

            #: (Hash[Symbol, untyped]) -> void
            def handle_session(data)
              session_id = data[:id]
              if session_id.present? && @result.session != session_id
                Event << { debug: "New Pi Session ID: #{session_id}" }
                @result.session = session_id
              end
            end

            #: (Hash[Symbol, untyped]) -> void
            def handle_message_update(data)
              event = data[:assistantMessageEvent]
              return unless event

              event_type = event[:type]&.to_sym

              case event_type
              when :text_delta
                delta = event[:delta]
                @current_text_block << delta if delta
              when :text_end
                content = event[:content]
                if content.present?
                  @result.response = content
                elsif @current_text_block.present?
                  @result.response = @current_text_block.dup
                end
                # Print the accumulated text block as a single unit (like Claude does)
                puts @current_text_block if @current_text_block.present? && @show_progress
                @current_text_block = +""
              when :toolcall_end
                tool_call = event[:toolCall]
                if tool_call
                  tool_call_msg = Messages::ToolCallMessage.new(
                    id: tool_call[:id],
                    name: tool_call[:name],
                    arguments: tool_call[:arguments] || {},
                  )
                  @context.add_tool_call(tool_call_msg)
                end
              end
            end

            #: (Hash[Symbol, untyped]) -> void
            def handle_message_end(data)
              message = data[:message]
              return unless message

              role = message[:role]&.to_sym

              case role
              when :assistant
                # Extract usage from the final assistant message_end
                usage = message[:usage]
                model = message[:model]
                if usage && model
                  accumulate_usage(model, usage)
                end

                # Extract final text if present
                content = message[:content]
                if content.is_a?(Array)
                  text_parts = content.select { |c| c[:type] == "text" }.map { |c| c[:text] }
                  @result.response = text_parts.join if text_parts.any?
                end
              end
            end

            #: (Hash[Symbol, untyped]) -> void
            def handle_tool_execution_start(data)
              tool_name = data[:toolName]
              args = data[:args]
              return unless @show_progress && tool_name

              formatted = Messages::ToolCallMessage.new(
                id: data[:toolCallId],
                name: tool_name,
                arguments: args || {},
              ).format
              puts formatted if formatted.present?
            end

            #: (Hash[Symbol, untyped]) -> void
            def handle_tool_execution_end(data)
              return unless @show_progress

              result_data = data[:result]
              content = result_data&.dig(:content)&.first&.dig(:text) if result_data
              formatted = Messages::ToolResultMessage.new(
                tool_call_id: data[:toolCallId],
                tool_name: data[:toolName],
                content: content,
                is_error: data[:isError] || false,
              ).format(@context)
              puts formatted if formatted.present?
            end

            #: (Hash[Symbol, untyped]) -> void
            def handle_agent_end(data)
              # Extract final response from the last assistant message
              messages = data[:messages]
              return unless messages.is_a?(Array)

              last_assistant = messages.reverse.find { |m| m[:role] == "assistant" }
              return unless last_assistant

              content = last_assistant[:content]
              if content.is_a?(Array)
                text_parts = content.select { |c| c[:type] == "text" }.map { |c| c[:text] }
                @result.response = text_parts.join if text_parts.any?
              end
            end

            #: (String, Hash[Symbol, untyped]) -> void
            def accumulate_usage(model, usage)
              acc = @model_usage_accumulator[model] ||= { input: 0, output: 0, cache_read: 0, cache_write: 0, cost: 0.0 }
              acc[:input] = (acc[:input] || 0) + (usage[:input] || 0)
              acc[:output] = (acc[:output] || 0) + (usage[:output] || 0)
              acc[:cache_read] = (acc[:cache_read] || 0) + (usage[:cacheRead] || 0)
              acc[:cache_write] = (acc[:cache_write] || 0) + (usage[:cacheWrite] || 0)
              cost = usage.dig(:cost, :total) || 0.0
              acc[:cost] = (acc[:cost] || 0.0) + cost
              @total_cost = @model_usage_accumulator.values.sum(0.0) { |a| a[:cost].to_f }
            end

            #: () -> void
            def finalize_stats!
              stats = Stats.new
              stats.num_turns = @num_turns
              stats.duration_ms = @end_time_ms - @start_time_ms if @start_time_ms && @end_time_ms

              @model_usage_accumulator.each do |model, acc|
                usage = Usage.new
                usage.input_tokens = acc[:input].to_i
                usage.output_tokens = acc[:output].to_i
                usage.cost_usd = acc[:cost].to_f
                stats.model_usage[model] = usage
                stats.usage.input_tokens = (stats.usage.input_tokens || 0) + (usage.input_tokens || 0)
                stats.usage.output_tokens = (stats.usage.output_tokens || 0) + (usage.output_tokens || 0)
              end
              stats.usage.cost_usd = @total_cost

              @result.stats = stats
            end

            #: () -> Array[String]
            def command_line
              command = if @base_command.is_a?(Array)
                @base_command.dup
              elsif @base_command.is_a?(String)
                @base_command.split
              else
                ["pi"]
              end
              command.push("--mode", "json", "-p")
              command.push("--model", @model) if @model
              command.push("--system-prompt", @replace_system_prompt) if @replace_system_prompt
              command.push("--append-system-prompt", @append_system_prompt) if @append_system_prompt
              if @session.present?
                command.push("--fork", @session)
              else
                command.push("--no-session")
              end
              command
            end
          end
        end
      end
    end
  end
end
