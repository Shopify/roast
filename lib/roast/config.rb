# frozen_string_literal: true

module Roast
  class Config
    autoload :Initializers, "roast/config/initializers"
    autoload :Cache, "roast/config/cache"

    class << self
      def root(starting_path = Dir.pwd, ending_path = File.dirname(Dir.home))
        candidate = starting_path
        while candidate != ending_path
          break if Dir.exist?(File.join(candidate, ".roast"))

          candidate = File.dirname(candidate)
        end

        File.join(candidate, ".roast")
      end
    end
  end
end
