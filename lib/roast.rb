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
require "pathname"
require "securerandom"
require "shellwords"
require "tempfile"
require "timeout"
require "uri"
require "yaml"
require "optparse"

# Third-party gem requires
require "active_support"
require "active_support/cache"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/string"
require "active_support/core_ext/string/inflections"
require "active_support/isolated_execution_state"
require "active_support/notifications"
require "cli/ui"
require "cli/kit"
require "diff/lcs"
require "json-schema"
require "raix"
require "raix/chat_completion"
require "raix/function_dispatch"
require "ruby-graphviz"
require "timeout"

# Autoloading setup
require "zeitwerk"

# Set up Zeitwerk autoloader
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("dsl" => "DSL")
loader.setup

module Roast
  ROOT = File.expand_path("../..", __FILE__)

  Abort = CLI::Kit::Abort
  AbortSilent = CLI::Kit::AbortSilent
end
