# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

# If you have untrusted strings you want to use in `cmd` cog shell commands,
# you have several built-in options for safety

config do
  cmd { display! }
end

execute do
  cmd(:attack_succeeds) do
    bad_param = "; echo bad"
    "echo hello world #{bad_param}"
  end

  cmd(:attack_fails_because_of_sanitization) do
    # Use `.shellescape` on any untrusted strings you're interpolating into shell command strings
    bad_param = "; echo bad"
    "echo hello world #{bad_param.shellescape}"
  end

  cmd(:attack_fails_because_of_explicit_args) do |my|
    # Use an array of arguments instead of string interpolation. This skips the shell entirely and just run the command.
    bad_param = "; echo bad"
    my.command = "echo"
    my.args = ["hello", "world", bad_param]
  end

  cmd(:attack_fails_because_of_explicit_args_shorthand) do
    # Simply returning an array instead of a string is convenient shorthand
    bad_param = "; echo bad"
    ["echo", "hello", "world", bad_param]
  end
end
