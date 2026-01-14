# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
  cmd { display! }
  cmd(:alt) { working_directory "/tmp" }
  cmd(:orig) { use_current_working_directory! }
end

execute do
  cmd(:cwd) { "echo Current working directory: `pwd`" }
  cmd(:alt) { "echo Alternate working directory: `pwd`" }
  cmd(:orig) { "echo Back to original working directory: `pwd`" }
end
