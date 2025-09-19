# typed: true
# frozen_string_literal: true

module Roast
  module TUI
    class ToolRegistry
      class Tool
        attr_reader :name, :description, :parameters, :handler, :parallel_safe

        def initialize(name:, description:, parameters:, handler:, parallel_safe: true)
          @name = name
          @description = description
          @parameters = parameters
          @handler = handler
          @parallel_safe = parallel_safe
        end

        def execute(arguments)
          validate_arguments(arguments)
          @handler.call(arguments)
        end

        def to_openai_format
          {
            type: "function",
            function: {
              name: @name,
              description: @description,
              parameters: @parameters
            }
          }
        end

        private

        def validate_arguments(arguments)
          return unless @parameters["required"]
          
          missing = @parameters["required"] - arguments.keys.map(&:to_s)
          unless missing.empty?
            raise ArgumentError, "Missing required parameters for #{@name}: #{missing.join(", ")}"
          end
        end
      end

      def initialize
        @tools = {}
        @parallel_execution = true
        register_default_tools
      end

      def register(name:, description:, parameters:, parallel_safe: true, &handler)
        @tools[name] = Tool.new(
          name: name,
          description: description,
          parameters: parameters,
          handler: handler || proc { |args| raise "No handler defined for tool: #{name}" },
          parallel_safe: parallel_safe
        )
      end

      def unregister(name)
        @tools.delete(name)
      end

      def execute(name, arguments)
        tool = @tools[name]
        raise "Unknown tool: #{name}" unless tool
        
        tool.execute(arguments)
      end

      def has_tools?
        !@tools.empty?
      end

      def tool_names
        @tools.keys
      end

      def get_tool(name)
        @tools[name]
      end

      def to_openai_format
        @tools.values.map(&:to_openai_format)
      end

      def supports_parallel?
        @parallel_execution && @tools.values.all?(&:parallel_safe)
      end

      def enable_parallel_execution
        @parallel_execution = true
      end

      def disable_parallel_execution
        @parallel_execution = false
      end

      private

      def register_default_tools
        register_file_tools
        register_shell_tools
        register_web_tools
      end

      def register_file_tools
        # Read file tool
        register(
          name: "read_file",
          description: "Read the contents of a file",
          parameters: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "The path to the file to read"
              }
            },
            required: ["path"]
          }
        ) do |args|
          path = File.expand_path(args["path"])
          raise "File not found: #{path}" unless File.exist?(path)
          raise "Path is a directory: #{path}" if File.directory?(path)
          
          File.read(path)
        end

        # Write file tool
        register(
          name: "write_file",
          description: "Write content to a file",
          parameters: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "The path where the file should be written"
              },
              content: {
                type: "string",
                description: "The content to write to the file"
              }
            },
            required: ["path", "content"]
          },
          parallel_safe: false
        ) do |args|
          path = File.expand_path(args["path"])
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, args["content"])
          "File written successfully to #{path}"
        end

        # List directory tool
        register(
          name: "list_directory",
          description: "List the contents of a directory",
          parameters: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "The path to the directory to list"
              },
              recursive: {
                type: "boolean",
                description: "Whether to list recursively",
                default: false
              }
            },
            required: ["path"]
          }
        ) do |args|
          path = File.expand_path(args["path"])
          raise "Directory not found: #{path}" unless File.exist?(path)
          raise "Path is not a directory: #{path}" unless File.directory?(path)
          
          if args["recursive"]
            Dir.glob(File.join(path, "**", "*")).map { |f| f.sub("#{path}/", "") }
          else
            Dir.entries(path).reject { |f| f.start_with?(".") }
          end
        end
      end

      def register_shell_tools
        # Execute shell command tool
        register(
          name: "execute_command",
          description: "Execute a shell command and return the output",
          parameters: {
            type: "object",
            properties: {
              command: {
                type: "string",
                description: "The shell command to execute"
              },
              working_directory: {
                type: "string",
                description: "The working directory for the command (optional)"
              }
            },
            required: ["command"]
          },
          parallel_safe: false
        ) do |args|
          require "open3"
          
          options = {}
          options[:chdir] = File.expand_path(args["working_directory"]) if args["working_directory"]
          
          stdout, stderr, status = Open3.capture3(args["command"], **options)
          
          {
            stdout: stdout,
            stderr: stderr,
            exit_code: status.exitstatus,
            success: status.success?
          }
        end
      end

      def register_web_tools
        # HTTP request tool
        register(
          name: "http_request",
          description: "Make an HTTP request and return the response",
          parameters: {
            type: "object",
            properties: {
              url: {
                type: "string",
                description: "The URL to request"
              },
              method: {
                type: "string",
                enum: ["GET", "POST", "PUT", "DELETE", "PATCH"],
                description: "The HTTP method to use",
                default: "GET"
              },
              headers: {
                type: "object",
                description: "Optional headers to include in the request"
              },
              body: {
                type: "string",
                description: "Optional body for POST/PUT/PATCH requests"
              }
            },
            required: ["url"]
          }
        ) do |args|
          require "net/http"
          require "json"
          
          uri = URI(args["url"])
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"
          
          method_class = case args["method"] || "GET"
          when "GET" then Net::HTTP::Get
          when "POST" then Net::HTTP::Post
          when "PUT" then Net::HTTP::Put
          when "DELETE" then Net::HTTP::Delete
          when "PATCH" then Net::HTTP::Patch
          else
            raise "Unsupported HTTP method: #{args["method"]}"
          end
          
          request = method_class.new(uri.request_uri)
          
          # Add headers
          if args["headers"]
            args["headers"].each { |k, v| request[k] = v }
          end
          
          # Add body
          if args["body"] && %w[POST PUT PATCH].include?(args["method"])
            request.body = args["body"]
            request["Content-Type"] = "application/json" unless request["Content-Type"]
          end
          
          response = http.request(request)
          
          {
            status_code: response.code.to_i,
            headers: response.each_header.to_h,
            body: response.body
          }
        end
      end

      class << self
        # Factory method to create a registry with specific tools
        def create_with_tools(tool_specs)
          registry = new
          
          tool_specs.each do |spec|
            registry.register(
              name: spec[:name],
              description: spec[:description],
              parameters: spec[:parameters],
              parallel_safe: spec[:parallel_safe] || true,
              &spec[:handler]
            )
          end
          
          registry
        end

        # Create a minimal registry without default tools
        def create_minimal
          registry = allocate
          registry.instance_variable_set(:@tools, {})
          registry.instance_variable_set(:@parallel_execution, true)
          registry
        end
      end
    end
  end
end