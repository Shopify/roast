# typed: true
# frozen_string_literal: true

require "open3"
require "timeout"
require "net/http"
require "uri"
require "json"

module Roast
  module TUI
    module Tools
      class SystemOperations
        # Bash command execution tool
        class Bash < Base
          # Track running background processes
          @@background_processes = {}
          @@process_mutex = Mutex.new

          def initialize
            super(
              name: "bash",
              description: "Execute shell commands with timeout and background support",
              parameters: {
                type: "object",
                properties: {
                  command: Base.string_param("The shell command to execute", required: true),
                  description: Base.string_param("Brief description of what the command does"),
                  timeout: Base.integer_param("Timeout in milliseconds", minimum: 1, maximum: 600000, default: 120000),
                  run_in_background: Base.boolean_param("Run command in background", default: false),
                  working_directory: Base.string_param("Working directory for command execution"),
                  env: Base.object_param("Environment variables to set")
                },
                required: ["command"]
              },
              permission_mode: :ask
            )
          end

          def parallel_safe?
            false
          end

          def perform(arguments, context)
            command = arguments["command"]
            timeout_ms = arguments["timeout"] || 120000
            timeout_sec = timeout_ms / 1000.0
            run_in_background = arguments["run_in_background"]
            
            if run_in_background
              execute_background(command, arguments, context)
            else
              execute_foreground(command, arguments, timeout_sec, context)
            end
          end

          private

          def execute_foreground(command, arguments, timeout_sec, context)
            options = build_options(arguments)
            
            begin
              result = nil
              
              Timeout.timeout(timeout_sec) do
                stdin, stdout, stderr, wait_thread = Open3.popen3(command, **options)
                stdin.close
                
                # Stream output if in interactive mode
                if context[:interactive] && context[:stream_output]
                  stream_output(stdout, stderr)
                  status = wait_thread.value
                  result = {
                    stdout: "",
                    stderr: "",
                    exit_code: status.exitstatus,
                    success: status.success?
                  }
                else
                  stdout_data = stdout.read
                  stderr_data = stderr.read
                  status = wait_thread.value
                  
                  result = {
                    stdout: truncate_output(stdout_data),
                    stderr: truncate_output(stderr_data),
                    exit_code: status.exitstatus,
                    success: status.success?
                  }
                end
                
                stdout.close
                stderr.close
              end
              
              format_bash_result(result, arguments["description"])
              
            rescue Timeout::Error
              raise ValidationError, "Command timed out after #{timeout_sec} seconds"
            rescue StandardError => e
              raise ValidationError, "Command failed: #{e.message}"
            end
          end

          def execute_background(command, arguments, context)
            options = build_options(arguments)
            process_id = generate_process_id
            
            @@process_mutex.synchronize do
              stdin, stdout, stderr, wait_thread = Open3.popen3(command, **options)
              stdin.close
              
              @@background_processes[process_id] = {
                command: command,
                description: arguments["description"],
                stdout: stdout,
                stderr: stderr,
                thread: wait_thread,
                output_buffer: [],
                started_at: Time.now,
                status: :running
              }
            end
            
            # Start output collection thread
            Thread.new do
              collect_background_output(process_id)
            end
            
            "Started background process: #{process_id}\nCommand: #{command}\nUse 'bash_output' tool to check output"
          end

          def collect_background_output(process_id)
            process = @@background_processes[process_id]
            return unless process
            
            stdout = process[:stdout]
            stderr = process[:stderr]
            
            loop do
              ready = IO.select([stdout, stderr], nil, nil, 0.1)
              
              if ready
                ready[0].each do |io|
                  begin
                    line = io.read_nonblock(4096)
                    @@process_mutex.synchronize do
                      process[:output_buffer] << line
                      # Keep buffer size reasonable
                      if process[:output_buffer].size > 1000
                        process[:output_buffer].shift
                      end
                    end
                  rescue IO::WaitReadable
                    # No data available yet
                  rescue EOFError
                    # Stream closed
                  end
                end
              end
              
              # Check if process is done
              if !process[:thread].alive?
                @@process_mutex.synchronize do
                  process[:status] = :completed
                  process[:exit_code] = process[:thread].value.exitstatus
                end
                break
              end
            end
            
            stdout.close rescue nil
            stderr.close rescue nil
          end

          def build_options(arguments)
            options = {}
            
            if arguments["working_directory"]
              dir = File.expand_path(arguments["working_directory"])
              raise ValidationError, "Directory not found: #{dir}" unless File.directory?(dir)
              options[:chdir] = dir
            end
            
            if arguments["env"]
              options[:env] = arguments["env"]
            end
            
            options
          end

          def stream_output(stdout, stderr)
            # Stream output in real-time for interactive mode
            threads = []
            
            threads << Thread.new do
              stdout.each_line do |line|
                CLI::UI.puts(line.chomp)
              end
            end
            
            threads << Thread.new do
              stderr.each_line do |line|
                CLI::UI.puts("{{red:#{line.chomp}}}", to: :stderr)
              end
            end
            
            threads.each(&:join)
          end

          def truncate_output(output, max_chars = 30000)
            return output if output.bytesize <= max_chars
            
            truncated = output[0...max_chars]
            truncated + "\n... (output truncated at #{max_chars} characters)"
          end

          def format_bash_result(result, description)
            output = []
            
            output << "Command: #{description}" if description
            output << "Exit code: #{result[:exit_code]}"
            output << "Status: #{result[:success] ? 'Success' : 'Failed'}"
            
            unless result[:stdout].empty?
              output << "\nStdout:"
              output << result[:stdout]
            end
            
            unless result[:stderr].empty?
              output << "\nStderr:"
              output << result[:stderr]
            end
            
            output.join("\n")
          end

          def generate_process_id
            "bash_#{Time.now.to_i}_#{rand(1000)}"
          end

          class << self
            def get_background_process(process_id)
              @@background_processes[process_id]
            end

            def list_background_processes
              @@background_processes.map do |id, process|
                {
                  id: id,
                  command: process[:command],
                  status: process[:status],
                  started_at: process[:started_at]
                }
              end
            end

            def kill_background_process(process_id)
              process = @@background_processes[process_id]
              return false unless process
              
              begin
                Process.kill("TERM", process[:thread].pid)
                process[:thread].join(5) # Wait up to 5 seconds
                
                if process[:thread].alive?
                  Process.kill("KILL", process[:thread].pid)
                end
                
                @@process_mutex.synchronize do
                  process[:status] = :killed
                  process[:stdout].close rescue nil
                  process[:stderr].close rescue nil
                end
                
                true
              rescue StandardError => e
                false
              end
            end
          end
        end

        # Tool to get output from background bash processes
        class BashOutput < Base
          def initialize
            super(
              name: "bash_output",
              description: "Retrieve output from a background bash process",
              parameters: {
                type: "object",
                properties: {
                  bash_id: Base.string_param("The ID of the background process", required: true),
                  filter: Base.string_param("Optional regex to filter output lines")
                },
                required: ["bash_id"]
              }
            )
          end

          def perform(arguments, context)
            process = Bash.get_background_process(arguments["bash_id"])
            
            raise ValidationError, "Process not found: #{arguments["bash_id"]}" unless process
            
            output = []
            
            # Get new output since last check
            @@process_mutex.synchronize do
              output = process[:output_buffer].dup
              process[:output_buffer].clear
            end
            
            # Apply filter if specified
            if arguments["filter"]
              regex = Regexp.new(arguments["filter"])
              output.select! { |line| line.match?(regex) }
            end
            
            result = {
              process_id: arguments["bash_id"],
              status: process[:status],
              output: output.join,
              exit_code: process[:exit_code]
            }
            
            format_output_result(result)
          end

          private

          def format_output_result(result)
            lines = []
            lines << "Process: #{result[:process_id]}"
            lines << "Status: #{result[:status]}"
            lines << "Exit code: #{result[:exit_code]}" if result[:exit_code]
            
            unless result[:output].empty?
              lines << "\nOutput:"
              lines << result[:output]
            else
              lines << "\n(No new output)"
            end
            
            lines.join("\n")
          end
        end

        # Tool to kill background bash processes
        class KillBash < Base
          def initialize
            super(
              name: "kill_bash",
              description: "Kill a background bash process",
              parameters: {
                type: "object",
                properties: {
                  shell_id: Base.string_param("The ID of the background process to kill", required: true)
                },
                required: ["shell_id"]
              },
              permission_mode: :ask
            )
          end

          def parallel_safe?
            false
          end

          def perform(arguments, context)
            success = Bash.kill_background_process(arguments["shell_id"])
            
            if success
              "Successfully killed process: #{arguments["shell_id"]}"
            else
              raise ValidationError, "Failed to kill process: #{arguments["shell_id"]}"
            end
          end
        end

        # Web fetch tool
        class WebFetch < Base
          def initialize
            super(
              name: "webfetch",
              description: "Fetch and process web content",
              parameters: {
                type: "object",
                properties: {
                  url: Base.string_param("The URL to fetch", required: true),
                  prompt: Base.string_param("Prompt to process the fetched content", required: true),
                  method: Base.string_param("HTTP method", enum: ["GET", "POST"], default: "GET"),
                  headers: Base.object_param("Additional headers to send"),
                  body: Base.string_param("Request body for POST requests"),
                  follow_redirects: Base.boolean_param("Follow redirects", default: true),
                  timeout: Base.integer_param("Timeout in seconds", minimum: 1, maximum: 60, default: 30)
                },
                required: ["url", "prompt"]
              }
            )
          end

          def perform(arguments, context)
            url = normalize_url(arguments["url"])
            
            # Fetch the content
            content = fetch_url(url, arguments)
            
            # Process with the prompt
            process_content(content, arguments["prompt"], url)
          end

          private

          def normalize_url(url)
            # Ensure URL has a scheme
            unless url.match?(/^https?:\/\//)
              url = "https://#{url}"
            end
            
            URI(url)
          rescue URI::InvalidURIError => e
            raise ValidationError, "Invalid URL: #{e.message}"
          end

          def fetch_url(uri, arguments)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = uri.scheme == "https"
            http.open_timeout = arguments["timeout"] || 30
            http.read_timeout = arguments["timeout"] || 30
            
            request = case arguments["method"]
                     when "POST"
                       req = Net::HTTP::Post.new(uri.request_uri)
                       req.body = arguments["body"] if arguments["body"]
                       req
                     else
                       Net::HTTP::Get.new(uri.request_uri)
                     end
            
            # Add headers
            request["User-Agent"] = "Roast TUI/1.0"
            if arguments["headers"]
              arguments["headers"].each { |k, v| request[k] = v }
            end
            
            response = http.request(request)
            
            # Handle redirects
            if response.is_a?(Net::HTTPRedirection) && arguments["follow_redirects"]
              location = response["location"]
              if location.start_with?("http")
                new_uri = URI(location)
              else
                new_uri = uri + location
              end
              
              # Check for redirect to different host
              if new_uri.host != uri.host
                return "Redirect to different host detected: #{new_uri}\nPlease make a new request with the redirect URL."
              end
              
              # Recursive call with new URL
              return fetch_url(new_uri, arguments.merge("follow_redirects" => false))
            end
            
            unless response.is_a?(Net::HTTPSuccess)
              raise ValidationError, "HTTP #{response.code}: #{response.message}"
            end
            
            response.body
          rescue Net::OpenTimeout, Net::ReadTimeout
            raise ValidationError, "Request timed out after #{arguments["timeout"]} seconds"
          rescue StandardError => e
            raise ValidationError, "Failed to fetch URL: #{e.message}"
          end

          def process_content(content, prompt, url)
            # Convert HTML to text if needed
            processed_content = if content.include?("<html") || content.include?("<HTML")
                                 strip_html(content)
                               else
                                 content
                               end
            
            # Truncate if too long
            max_length = 10000
            if processed_content.length > max_length
              processed_content = processed_content[0...max_length] + "\n... (content truncated)"
            end
            
            # Format result
            result = []
            result << "URL: #{url}"
            result << "Content length: #{content.bytesize} bytes"
            result << "\n--- Processed Content ---"
            result << apply_prompt(processed_content, prompt)
            
            result.join("\n")
          end

          def strip_html(html)
            # Basic HTML stripping
            html
              .gsub(/<script[^>]*>.*?<\/script>/mi, "") # Remove scripts
              .gsub(/<style[^>]*>.*?<\/style>/mi, "")   # Remove styles
              .gsub(/<[^>]+>/, " ")                     # Remove tags
              .gsub(/\s+/, " ")                         # Normalize whitespace
              .strip
          end

          def apply_prompt(content, prompt)
            # In a real implementation, this would call an LLM
            # For now, we'll just return a summary
            lines = content.lines.first(20)
            
            "Prompt: #{prompt}\n\nContent preview:\n#{lines.join}"
          end
        end

        class << self
          def register_all(registry)
            registry.register(
              name: "bash",
              description: Bash.new.description,
              parameters: Bash.new.parameters,
              parallel_safe: false
            ) { |args| Bash.new.execute(args) }

            registry.register(
              name: "bash_output",
              description: BashOutput.new.description,
              parameters: BashOutput.new.parameters,
              parallel_safe: true
            ) { |args| BashOutput.new.execute(args) }

            registry.register(
              name: "kill_bash",
              description: KillBash.new.description,
              parameters: KillBash.new.parameters,
              parallel_safe: false
            ) { |args| KillBash.new.execute(args) }

            registry.register(
              name: "webfetch",
              description: WebFetch.new.description,
              parameters: WebFetch.new.parameters,
              parallel_safe: true
            ) { |args| WebFetch.new.execute(args) }
          end
        end
      end
    end
  end
end