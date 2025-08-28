# typed: false
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class << self
        #: (String) -> void
        def load_all_for(rube_rb_fpath)
          rube_rb_fpath = File.expand_path(rube_rb_fpath)
          all_cog_files(rube_rb_fpath).each do |cog_fpath|
            require cog_fpath
          end
          bind_all_cog_invokers
        end

        #: () -> Array[Class]
        def all_cog_classes
          # rubocop:disable Sorbet/ConstantsFromStrings
          Roast::DSL::Cogs.constants.map do |cog_class_name|
            Roast::DSL::Cogs.const_get(cog_class_name)
          end
          # rubocop:enable Sorbet/ConstantsFromStrings
        end

        private

        #: () -> void
        def bind_all_cog_invokers
          all_cog_classes.each do |cog_class|
            # At some point we may want to tuck this all into a Roast::DSL::Binding/Scope/Context to avoid polluting toplevel.
            TOPLEVEL_BINDING.eval(binding_string_for(cog_class))
          end
        end

        #: (Class) -> String
        def binding_string_for(cog_class)
          <<~RUBY
            def #{cog_class.method_name}(*args, **kwargs, &block)
              #{cog_class.name}.invoke(*args, **kwargs, &block)
            end
          RUBY
        end

        #: (String) -> Array[String]
        def all_cog_files(rube_rb_fpath)
          dirs = [project_cogs_dir(rube_rb_fpath), internal_cogs_dir]
          dirs.map do |dir|
            Dir.glob(File.join(dir, "*.rb")) # Just toplevel .rb files
          end.flatten
        end

        #: (String) -> String
        def project_cogs_dir(rube_rb_fpath)
          File.join(File.dirname(rube_rb_fpath), "cogs")
        end

        #: () -> String
        def internal_cogs_dir
          File.join(File.dirname(__FILE__), "cogs")
        end
      end
    end
  end
end
