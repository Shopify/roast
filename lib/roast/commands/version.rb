# typed: true
# frozen_string_literal: true

module Roast
  module Commands
    class Version < Command
      def call(_args, _name)
        puts "Roast version #{Roast::VERSION}"
      end

      class << self
        def help
          <<~HELP
            Display the current version of Roast

            Usage: roast version
          HELP
        end
      end
    end
  end
end
