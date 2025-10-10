# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Config
      DEFAULT_FPATH = File.join(Roast::DSL::CONFIG_HOME, "config.json")

      class << self
        def get(*keys)
          keys.map!(&:to_s)
          current.dig(*keys)
        end

        def set(key, value)
          current[key] = value
          save
        end

        def current
          @current ||= load
        end

        def load(fpath: DEFAULT_FPATH)
          JSON.parse(File.read(fpath))
        rescue JSON::ParserError => e
          raise "Error parsing config file: #{e.message}"
        rescue Errno::ENOENT
          raise "Config file not found: #{fpath}"
        end

        def save(fpath: DEFAULT_FPATH)
          File.write(fpath, current.to_json)
        end
      end
    end
  end
end
