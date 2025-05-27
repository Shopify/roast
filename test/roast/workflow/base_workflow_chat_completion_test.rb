# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class BaseWorkflowChatCompletionTest < Minitest::Test
      class TestWorkflow < BaseWorkflow
        # Override to avoid loading prompt files
        def read_sidecar_prompt
          nil
        end
      end

      class MockConfiguration
        def api_provider
          "openai"
        end

        def openai?
          true
        end

        def context_management
          Roast::Workflow::ContextManagementConfig.new(enabled: false)
        end
      end

      def test_chat_completion_module_is_included_in_base_workflow
        workflow = TestWorkflow.new(nil, name: "test", configuration: MockConfiguration.new)

        # Verify that BaseWorkflow includes Raix::ChatCompletion
        assert(workflow.class.included_modules.include?(Raix::ChatCompletion))
      end

      def test_chat_completion_method_is_overridden
        TestWorkflow.new(nil, name: "test", configuration: MockConfiguration.new)

        # The chat_completion method should be defined on BaseWorkflow itself
        # (not just inherited from the module)
        assert(BaseWorkflow.instance_methods(false).include?(:chat_completion))
      end

      def test_chat_completion_responds_to_method
        workflow = TestWorkflow.new(nil, name: "test", configuration: MockConfiguration.new)

        # Verify the workflow responds to chat_completion
        assert(workflow.respond_to?(:chat_completion))
      end
    end
  end
end
