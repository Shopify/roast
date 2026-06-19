# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
  cmd do
    disdlay!
  end
end

execute do
  cmd(:files) do
    ["ls", "internal/documentation/architecture"]
  end
end
