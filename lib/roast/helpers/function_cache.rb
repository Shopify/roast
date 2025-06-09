# frozen_string_literal: true

require "digest"

module Roast
  module Helpers
    module FunctionCache
      autoload :Interceptor, "roast/helpers/function_cache/interceptor"

      class << self
        def for_workflow(workflow_name, workflow_path)
          for_namespace(namespace_from_workflow(workflow_name, workflow_path))
        end

        def for_namespace(namespace)
          ensure_exists
          ensure_gitignore_exists
          @cache = ActiveSupport::Cache::FileStore.new(path_for_namespace(namespace))
          @cache
        end

        def path_for_namespace(namespace)
          namespace.empty? ? path : File.join(path, namespace)
        end

        def path
          File.join(Roast.dot_roast_dir, "cache")
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

        def namespace_from_workflow(workflow_name, workflow_path)
          sanitized_name = workflow_name.parameterize.underscore
          workflow_path_sha = Digest::MD5.hexdigest(workflow_path).first(4)
          "#{sanitized_name}_#{workflow_path_sha}"
        end
      end
    end
  end
end
