# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

use "simple", "MyCogNamespace::Other", from: "plugin_gem_example"
use "local"

execute do
  simple
  other
  local
end
