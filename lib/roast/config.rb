# frozen_string_literal: true

module Roast
  class Config
    autoload :Initializers, "roast/config/initializers"
    autoload :Cache, "roast/config/cache"

    class << self
      def root(starting_path = Dir.pwd, ending_path = File.dirname(Dir.home))
        paths = []
        candidate = starting_path
        while candidate != ending_path
          paths << File.join(candidate, ".roast")
          candidate = File.dirname(candidate)
        end

        first_existing = paths.find { |path| Dir.exist?(path) }
        first_existing || paths.first
      end
    end
  end
end
