# typed: false
# frozen_string_literal: true

# How do we pass information between steps?
# Demonstrate by passing result of a command output to another step

config do
  cmd(:echo) { display! }
end

execute do
  cmd(:ls) { "ls -al" }
  cmd(:echo) do
    # TODO: this is a bespoke output object for cmd, is there a generic one we can offer
    first_line = cmd(:ls).out.split("\n").second
    "echo '#{first_line}'"
  end
end
