# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        module Providers
          class Claude < Base
            #: (String) -> String
            def invoke(prompt)
              # Use CmdRunner to execute claude CLI
              stdout, stderr, status = Roast::Helpers::CmdRunner.capture3("claude", "-p", prompt)

              unless status&.success?
                raise "Claude command failed: #{stderr}"
              end

              stdout&.strip || ""
            end
          end
        end
      end
    end
  end
end
