# typed: true
# frozen_string_literal: true

# Standard library requires
require "digest"
require "English"
require "erb"
require "fileutils"
require "json"
require "logger"
require "net/http"
require "open3"
require "optparse"
require "pathname"
require "securerandom"
require "shellwords"
require "tempfile"
require "timeout"
require "uri"
require "yaml"

# Third-party gem requires
require "active_support"
require "active_support/cache"
require "active_support/core_ext/array"
require "active_support/core_ext/hash"
require "active_support/core_ext/object/deep_dup"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/string"
require "active_support/core_ext/string/inflections"
require "active_support/isolated_execution_state"
require "active_support/notifications"
require "async"
require "async/semaphore"
require "ruby_llm"

# Require project components that will not get automatically loaded
require "roast/nil_assertions"

# Autoloading setup
require "zeitwerk"

# Set up Zeitwerk autoloader
loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/roast-ai.rb")
loader.inflector.inflect("cli" => "CLI")
loader.setup

module Roast
end
