# typed: false
# frozen_string_literal: true

module Roast
  module Tools
    module AskUser
      extend self

      class << self
        # Add this method to be included in other classes
        def included(base)
          base.class_eval do
            function(
              :ask_user,
              "Ask the user for input with a specific prompt. Returns the user's response.",
              prompt: { type: "string", description: "The prompt to show the user" },
            ) do |params|
              Roast::Tools::AskUser.call(params[:prompt])
            end
          end
        end
      end

      def call(prompt)
        Roast::Helpers::Logger.info("💬 Asking user: #{prompt}\n")

        response = ::CLI::UI::Prompt.ask(prompt)

        Roast::Helpers::Logger.info("User responded: #{response}\n")
        response
      rescue Roast::Error => e
        "Error getting user input: #{e.message}".tap do |error_message|
          Roast::Helpers::Logger.error(error_message + "\n")
          Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        end
      end
    end
  end
end
