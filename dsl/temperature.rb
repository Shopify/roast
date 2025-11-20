# typed: false
# frozen_string_literal: true

config do
  chat(:low_temp) do
    assume_model_exists!
    temperature(0.0)
  end

  chat(:high_temp) do
    assume_model_exists!
    temperature(1.0)
  end
end

execute do
  chat(:low_temp) { "Write a haiku about the capital of France." }
  chat(:high_temp) { "Write a haiku about the capital of France." }
end
