# frozen_string_literal: true

require "json"
require "logger"
require "yaml"
require "set"
require "stringio"
require "roast"
require "roast/workflow/configuration_parser"

module Roast
  module Commands
    class McpServer
      VERSION = "2024-11-05"
      # Support multiple protocol versions for compatibility
      SUPPORTED_VERSIONS = [
        "2024-11-05",  # Current standard version
        "2024-11-15",  # Newer version some clients use
        "2025-03-26",  # Latest version from dev server
        "0.1.0",       # Early version
        "1.0",         # Common version
        "1.0.0",       # Common version with patch
      ].freeze

      SERVER_CAPABILITIES = {
        "tools" => {
          "listChanged" => false,
        },
        "prompts" => { "listChanged" => false },
        "resources" => { "listChanged" => false },
        "completions" => false, # For 2024-11-05 format
      }.freeze

      INITIALIZATION_EXEMPT_METHODS = [
        "initialize", "ping", "shutdown", "notifications/initialized",
      ].freeze

      attr_reader :tools, :initialized

      def initialize(workflow_dirs: [], log_level: nil)
        @workflow_dirs = workflow_dirs
        @tools = []
        @tools_map = {}
        @initialized = false
        @logger = Logger.new($stderr)

        # Set log level if provided
        if log_level
          level = begin
            Logger.const_get(log_level.upcase)
          rescue
            Logger::INFO
          end
          @logger.level = level
        end

        discover_workflows
      end

      def run
        @logger.info("MCP Server starting...")
        @logger.info("Ruby version: #{RUBY_VERSION}")
        @logger.info("Working directory: #{Dir.pwd}")
        @logger.info("Available workflows: #{@tools.map { |t| t["name"] }.join(", ")}")

        begin
          loop do
            line = $stdin.gets
            break unless line

            begin
              request = JSON.parse(line.chomp)
              @logger.debug("Received request: #{request.inspect}")
              response = process_message(request)

              unless response.empty?
                @logger.debug("Sending response: #{response.inspect}")
                puts JSON.generate(response)
                $stdout.flush
              end
            rescue JSON::ParserError => e
              error_response = {
                "jsonrpc" => "2.0",
                "id" => nil,
                "error" => {
                  "code" => -32700,
                  "message" => "Parse error: #{e.message}",
                },
              }
              puts JSON.generate(error_response)
              $stdout.flush
            rescue StandardError => e
              @logger.error("Error processing request: #{e.message}")
              @logger.error(e.backtrace.join("\n"))

              # Send error response if we have a request ID
              if defined?(request) && request.is_a?(Hash) && request["id"]
                error_resp = error_response(-32603, "Internal error: #{e.message}", request["id"])
                puts JSON.generate(error_resp)
                $stdout.flush
              end
            end
          end
        rescue StandardError => e
          @logger.error("Fatal error in MCP server: #{e.message}")
          @logger.error(e.backtrace.join("\n"))
          raise
        ensure
          @logger.info("MCP Server shutting down")
        end
      end

      private

      def discover_workflows
        workflow_files = []

        # Add default workflow directories
        default_dirs = [
          File.join(Dir.pwd, "workflows"),
          File.join(Dir.pwd, "roast_workflows"),
        ]

        (@workflow_dirs + default_dirs).uniq.each do |dir|
          next unless Dir.exist?(dir)

          workflow_files += Dir.glob(File.join(dir, "**", "*.yml"))
        end

        # Also check for individual workflow files in current directory
        workflow_files += Dir.glob("*.yml").select do |f|
          File.read(f).include?("steps:")
        end

        workflow_files.uniq.each do |workflow_path|
          register_workflow(workflow_path)
        end

        @logger.info("Discovered #{@tools.length} workflows")
      end

      def register_workflow(workflow_path)
        config = YAML.load_file(workflow_path)

        # Skip if not a valid workflow
        return unless config.is_a?(Hash) && config["steps"]

        name = config["name"] || File.basename(workflow_path, ".yml")
        description = config["description"] || "Roast workflow: #{name}"

        # Generate tool name from workflow name
        tool_name = "roast_#{name.downcase.gsub(/\s+/, "_")}"

        # Build input schema from workflow target configuration
        input_schema = build_input_schema(config)

        tool = {
          "name" => tool_name,
          "description" => description,
          "inputSchema" => input_schema,
        }

        @tools << tool
        @tools_map[tool_name] = workflow_path

        @logger.info("Registered workflow: #{tool_name} -> #{workflow_path}")
      rescue StandardError => e
        @logger.error("Failed to register workflow #{workflow_path}: #{e.message}")
      end

      def build_input_schema(config)
        schema = {
          "type" => "object",
          "properties" => {},
        }

        # If workflow has a target, add it as an optional parameter
        if config["target"]
          schema["properties"]["target"] = {
            "type" => "string",
            "description" => "Target file or input for the workflow",
          }
        end

        # If workflow has an 'each' field, it likely expects file input
        if config["each"]
          schema["properties"]["file"] = {
            "type" => "string",
            "description" => "File to process with this workflow",
          }
        end

        # Look for any interpolated variables in the workflow
        if config["steps"]
          variables = extract_variables(config)
          variables.each do |var|
            # Skip if we already added this property
            next if schema["properties"].key?(var)

            schema["properties"][var] = {
              "type" => "string",
              "description" => "Value for {{#{var}}} in the workflow",
            }
          end
        end

        # If no parameters were found, add a default file parameter
        # as many workflows expect file input even without explicit configuration
        if schema["properties"].empty?
          schema["properties"]["file"] = {
            "type" => "string",
            "description" => "File or input for the workflow",
          }
        end

        schema
      end

      def extract_variables(config)
        variables = Set.new

        config_str = config.to_s

        # Find {{variable}} patterns (mustache style)
        config_str.scan(/\{\{(\w+)\}\}/) do |match|
          variables << match[0]
        end

        # Find <%= workflow.variable %> patterns (ERB style)
        config_str.scan(/<%=\s*workflow\.(\w+)\s*%>/) do |match|
          variables << match[0]
        end

        # Find ENV['ROAST_VARIABLE'] patterns
        config_str.scan(/ENV\[['"]ROAST_(\w+)['"]\]/) do |match|
          variables << match[0].downcase
        end

        variables.to_a
      end

      def process_message(request)
        method = request["method"]

        unless INITIALIZATION_EXEMPT_METHODS.include?(method) || @initialized
          return error_response(-32002, "Server not initialized", request["id"])
        end

        case method
        when "initialize"
          handle_initialize(request)
        when "shutdown"
          handle_shutdown(request)
        when "tools/list"
          handle_tools_list(request)
        when "tools/call"
          handle_tools_call(request)
        when "prompts/list"
          handle_prompts_list(request)
        when "prompts/get"
          handle_prompts_get(request)
        when "resources/list"
          handle_resources_list(request)
        when "resources/read"
          handle_resources_read(request)
        when "ping"
          handle_ping(request)
        when "notifications/initialized"
          # Client notification that it's ready - no response needed
          {}
        else
          error_response(-32601, "Method not found: #{method}", request["id"])
        end
      end

      def handle_initialize(request)
        client_version = request.dig("params", "protocolVersion")

        @logger.info("Client requesting protocol version: #{client_version}")

        unless SUPPORTED_VERSIONS.include?(client_version)
          @logger.error("Unsupported protocol version: #{client_version}")
          return error_response(
            -32602,
            "Unsupported protocol version",
            request["id"],
            { "supported" => SUPPORTED_VERSIONS, "requested" => client_version },
          )
        end

        @initialized = true

        # Use the client's requested version if we support it
        response_version = SUPPORTED_VERSIONS.include?(client_version) ? client_version : VERSION

        # Adapt capabilities based on client version
        capabilities = adapt_capabilities(SERVER_CAPABILITIES.dup, client_version)

        {
          "jsonrpc" => "2.0",
          "id" => request["id"],
          "result" => {
            "protocolVersion" => response_version,
            "capabilities" => capabilities,
            "serverInfo" => {
              "name" => "roast-mcp-server",
              "version" => Roast::VERSION,
            },
          },
        }
      end

      def handle_shutdown(request)
        @initialized = false
        {
          "jsonrpc" => "2.0",
          "id" => request["id"],
          "result" => nil,
        }
      end

      def handle_tools_list(request)
        {
          "jsonrpc" => "2.0",
          "id" => request["id"],
          "result" => {
            "tools" => @tools,
          },
        }
      end

      def handle_tools_call(request)
        tool_name = request.dig("params", "name")
        arguments = request.dig("params", "arguments") || {}

        workflow_path = @tools_map[tool_name]

        unless workflow_path
          return error_response(-32602, "Tool not found: #{tool_name}", request["id"])
        end

        begin
          result = execute_workflow(workflow_path, arguments)

          {
            "jsonrpc" => "2.0",
            "id" => request["id"],
            "result" => {
              "content" => [
                {
                  "type" => "text",
                  "text" => result,
                },
              ],
              "isError" => false,
            },
          }
        rescue StandardError => e
          {
            "jsonrpc" => "2.0",
            "id" => request["id"],
            "result" => {
              "content" => [
                {
                  "type" => "text",
                  "text" => "Workflow execution failed: #{e.message}",
                },
              ],
              "isError" => true,
            },
          }
        end
      end

      def handle_ping(request)
        {
          "jsonrpc" => "2.0",
          "id" => request["id"],
          "result" => {},
        }
      end

      def handle_prompts_list(request)
        # Roast doesn't use prompts in the MCP sense, return empty list
        {
          "jsonrpc" => "2.0",
          "id" => request["id"],
          "result" => {
            "prompts" => [],
          },
        }
      end

      def handle_prompts_get(request)
        prompt_name = request.dig("params", "name")
        error_response(-32602, "Prompt '#{prompt_name}' not found", request["id"])
      end

      def handle_resources_list(request)
        # Roast doesn't expose resources, return empty list
        {
          "jsonrpc" => "2.0",
          "id" => request["id"],
          "result" => {
            "resources" => [],
          },
        }
      end

      def handle_resources_read(request)
        uri = request.dig("params", "uri")
        error_response(-32602, "Resource '#{uri}' not found", request["id"])
      end

      def execute_workflow(workflow_path, arguments)
        # Create a temporary output buffer to capture results
        output = StringIO.new
        original_stdout = $stdout
        original_stderr = $stderr

        begin
          # Redirect stdout/stderr to capture output
          $stdout = output
          $stderr = output

          # Set up workflow options
          options = {}

          # Handle target parameter - could be 'target' or 'file'
          if arguments["target"]
            options[:target] = arguments["target"]
          elsif arguments["file"]
            # If 'file' is provided but no 'target', use file as the target
            options[:target] = arguments["file"]
          end

          # Set environment variables for all arguments
          arguments.each do |key, value|
            ENV["ROAST_#{key.upcase}"] = value.to_s
          end

          # Run the workflow using ConfigurationParser like the CLI does
          Roast::Workflow::ConfigurationParser.new(workflow_path, [], options).begin!

          # Return the captured output
          output.string
        ensure
          # Restore stdout/stderr
          $stdout = original_stdout
          $stderr = original_stderr

          # Clean up environment variables
          arguments.each do |key, _|
            ENV.delete("ROAST_#{key.upcase}")
          end
        end
      end

      def error_response(code, message, id, data = nil)
        response = {
          "jsonrpc" => "2.0",
          "id" => id,
          "error" => {
            "code" => code,
            "message" => message,
          },
        }
        response["error"]["data"] = data if data
        response
      end

      def adapt_capabilities(capabilities, client_version)
        # Transform completions format for 2025-03-26 clients
        if client_version == "2025-03-26" && capabilities["completions"] == false
          capabilities["completions"] = { "enabled" => false }
        end
        capabilities
      end
    end
  end
end
