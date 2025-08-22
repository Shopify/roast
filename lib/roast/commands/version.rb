# typed: true
# frozen_string_literal: true

module Roast
  module Commands
    class Version < Command
      def invoke(_args, _name)
        puts "Roast version #{Roast::VERSION}"
      end

      def help_message
        <<~HELP
          Display the current version of Roast
          Usage: roast version
        HELP
      end
    end
  end
end
