# typed: false
# frozen_string_literal: true

execute do
  # This is a dead simple workflow that calls two commands
  cmd <<~CMDSTEP
    echo "I have no idea what's going on"
  CMDSTEP

  cmd "pwd"
end
