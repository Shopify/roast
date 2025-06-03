# frozen_string_literal: true

module Roast
  class Config
    class Cache
      class << self
        def for(key = "")
          ensure_exists
          ensure_gitignore_exists
          @cache = ActiveSupport::Cache::FileStore.new(path_for(key))
          @cache
        end

        def path_for(key)
          key.empty? ? path : File.join(path, key)
        end

        def path
          File.join(Config.root, "cache")
        end

        def ensure_exists
          FileUtils.mkdir_p(path) unless File.directory?(path)
        end

        def gitignore_path
          File.join(path, ".gitignore")
        end

        def ensure_gitignore_exists
          File.write(gitignore_path, "*") unless File.exist?(gitignore_path)
        end
      end
    end
  end
end
