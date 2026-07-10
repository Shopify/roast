# typed: true
# frozen_string_literal: true

module Roast
  class ConfigTier
    #: (^() -> Cog::Config) -> void
    def initialize(&config_factory)
      @config_factory = config_factory
      @general_config = config_factory.call
      @regexp_configs = {} #: Hash[Regexp, Cog::Config]
      @name_configs = {} #: Hash[Symbol, Cog::Config]
    end

    #: () -> Cog::Config
    attr_reader :general_config

    #: ((Symbol | Regexp)?) -> Cog::Config
    def fetch(name_or_pattern = nil)
      name_or_pattern = name_or_pattern #: untyped
      case name_or_pattern
      when NilClass
        @general_config
      when Regexp
        @regexp_configs[name_or_pattern] ||= @config_factory.call
      when Symbol
        @name_configs[name_or_pattern] ||= @config_factory.call
      else
        raise ArgumentError, "Invalid type '#{name_or_pattern.class}' for name_or_pattern"
      end
    end

    # Returns all matching configs in cascade order: general, then matching regexps, then name
    #: (Symbol?) -> Array[Cog::Config]
    def resolve(name)
      result = [@general_config]
      unless name.nil?
        @regexp_configs.each do |pattern, cfg|
          result << cfg if pattern.match?(name.to_s)
        end
        name_cfg = @name_configs[name]
        result << name_cfg if name_cfg
      end
      result
    end
  end
end
