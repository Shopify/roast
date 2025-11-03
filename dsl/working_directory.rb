# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  cmd { print_all! }
  cmd(:alt) { working_directory "/tmp" }
  cmd(:orig) { use_current_working_directory! }
end

execute do
  cmd(:cwd) { "echo Current working directory: `pwd`" }
  cmd(:alt) { "echo Alternate working directory: `pwd`" }
  cmd(:orig) { "echo Back to originl working directory: `pwd`" }
end
