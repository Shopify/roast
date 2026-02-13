# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

use "simple", from: "plugin_gem_example"
use "MyCogNamespace::Other", from: "plugin_gem_example"
use "local"

# Use multiple cogs
# use "simple", "other", from: "plugin_gem_example"

execute do
  simple
  other
  local
end
