# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    XDG_CONFIG_HOME = ENV.fetch("XDG_CONFIG_HOME", File.join(Dir.home, ".config"))

    CONFIG_HOME = File.join(XDG_CONFIG_HOME, "roast-dsl")
  end
end
