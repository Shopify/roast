# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# How do we pass information between steps?
# Demonstrate by passing result of a command output to another step

config do
  cmd(:echo) { display! }
end

execute do
  cmd(:ls) { "ls -al" }
  cmd(:echo) do |my|
    my.command = "echo"
    # TODO: this is a bespoke output object for cmd, is there a generic one we can offer
    first_line = cmd(:ls).out.split("\n").second
    last_line = cmd(:ls).out.split("\n").last
    my.args << first_line unless first_line.blank?
    my.args << "\n---\n"
    my.args << last_line if last_line != first_line && last_line.present?
  end
end
