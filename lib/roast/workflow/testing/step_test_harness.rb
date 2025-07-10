# frozen_string_literal: true

module Roast
  module Workflow
    module Testing
      # Test harness for running individual workflow steps in isolation
      class StepTestHarness
        attr_reader :step, :workflow, :transcript, :output, :performance_metrics

        def initialize(step_class, options = {})
          @step_class = step_class
          @options = options
          @transcript = []
          @output = {}
          @performance_metrics = {}

          setup_mock_workflow
          setup_step
        end

        # Execute the step and capture results
        def execute(input = nil)
          start_time = Time.now

          # Add input to transcript if provided
          @transcript << { user: input } if input

          # Execute the step
          begin
            result = @step.call
            @output[@step.name.to_s] = result

            # Capture performance metrics
            @performance_metrics[:execution_time] = Time.now - start_time
            @performance_metrics[:transcript_size] = @transcript.size

            StepExecutionResult.new(
              success: true,
              result: result,
              transcript: @transcript.dup,
              output: @output.dup,
              performance_metrics: @performance_metrics.dup,
              error: nil,
            )
          rescue StandardError => e
            @performance_metrics[:execution_time] = Time.now - start_time

            StepExecutionResult.new(
              success: false,
              result: nil,
              transcript: @transcript.dup,
              output: @output.dup,
              performance_metrics: @performance_metrics.dup,
              error: e,
            )
          end
        end

        # Configure the step with specific attributes
        def configure(attributes = {})
          attributes.each do |key, value|
            if @step.respond_to?("#{key}=")
              @step.send("#{key}=", value)
            else
              raise ArgumentError, "Step does not respond to #{key}="
            end
          end
          self
        end

        # Add a mock response for chat completion
        def with_mock_response(response, options = {})
          @workflow.add_mock_response(response, options)
          self
        end

        # Add multiple mock responses for sequential calls
        def with_mock_responses(*responses)
          responses.each { |response| with_mock_response(response) }
          self
        end

        # Set available tools for the step
        def with_tools(tools)
          @step.available_tools = tools
          self
        end

        # Set the resource for the step
        def with_resource(resource)
          @step.resource = resource
          @workflow.resource = resource
          self
        end

        # Add initial output to the workflow
        def with_initial_output(output)
          @output.merge!(output)
          self
        end

        # Add initial transcript entries
        def with_initial_transcript(*entries)
          @transcript.concat(entries)
          self
        end

        private

        def setup_mock_workflow
          @workflow = MockWorkflow.new(@output, @transcript, @options)
        end

        def setup_step
          step_options = @options.slice(:name, :model, :context_path)
          @step = @step_class.new(@workflow, **step_options)
        end
      end

      # Result object for step execution
      class StepExecutionResult
        attr_reader :result, :transcript, :output, :performance_metrics, :error

        def initialize(success:, result:, transcript:, output:, performance_metrics:, error:)
          @success = success
          @result = result
          @transcript = transcript
          @output = output
          @performance_metrics = performance_metrics
          @error = error
        end

        def success?
          @success
        end

        def failure?
          !@success
        end

        def execution_time
          @performance_metrics[:execution_time]
        end

        def transcript_size
          @performance_metrics[:transcript_size]
        end
      end

      # Mock workflow for testing steps in isolation
      class MockWorkflow
        attr_accessor :resource, :verbose, :concise, :file, :model
        attr_reader :transcript, :output, :appended_output, :chat_completion_calls

        def initialize(output = {}, transcript = [], options = {})
          @output = output
          @transcript = transcript
          @appended_output = []
          @chat_completion_calls = []
          @mock_responses = []
          @verbose = options[:verbose] || false
          @concise = options[:concise] || false
          @file = options[:file]
          @model = options[:model] || "anthropic:claude-opus-4"
          @resource = options[:resource]
        end

        def append_to_final_output(text)
          @appended_output << text
        end

        def chat_completion(**kwargs)
          @chat_completion_calls << kwargs

          # Get the next mock response or use default
          response = if @mock_responses.any?
            mock = @mock_responses.shift
            mock[:options]&.each do |key, value|
              unless kwargs[key] == value
                raise "Expected #{key}: #{value}, got #{kwargs[key]}"
              end
            end
            mock[:response]
          else
            kwargs[:json] ? { "result" => "mock json response" } : "mock response"
          end

          # Simulate adding assistant response to transcript
          @transcript << { assistant: response }
          response
        end

        def openai?
          @model&.start_with?("gpt") || false
        end

        def tools
          nil
        end

        def state
          @output
        end

        def respond_to?(method)
          [:output, :transcript, :resource, :state, :verbose, :concise, :file].include?(method) || super
        end

        def add_mock_response(response, options = {})
          @mock_responses << { response: response, options: options }
        end
      end
    end
  end
end
