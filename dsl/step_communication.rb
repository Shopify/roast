# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# How do we pass information between steps?
# Demonstrate by passing result of a command output to another step

config do
  cmd(:echo) { display! }
end

execute do
  cmd(:ls) do
    Async do |task|
      task.print_hierarchy($stdout)
    end
    ::CLI::UI::Frame.open("Inner") do
      puts "Hello"
    end
    puts "whooo"
    $console_interface << "start"
    "ls -al"
  end
  cmd(:echo) do |my|
    my.command = "echo"
    first_line = cmd!(:ls).lines.second
    last_line = cmd!(:ls).lines.last
    my.args << first_line unless first_line.blank?
    my.args << "\n---\n"
    my.args << last_line if last_line != first_line && last_line.present?
    $console_interface.put("hello world", true)
  end
end
