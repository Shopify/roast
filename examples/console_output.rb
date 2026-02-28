# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
  cmd { display! }
end

execute do
  cmd(:out) { "echo hello world" }
  cmd(:err) { "echo goodnight moon >&2" }
end
