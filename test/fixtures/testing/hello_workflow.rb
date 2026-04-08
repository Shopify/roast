# typed: false
# frozen_string_literal: true

#: self as Roast::Workflow

execute do
  cmd(:hello) { "echo hello from sandbox" }
end
