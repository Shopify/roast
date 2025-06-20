# frozen_string_literal: true

class SimpleRetry < Roast::Workflow::BaseStep
  def call
    # Simulate an API call that might fail
    @attempt ||= 0
    @attempt += 1

    puts "Attempt #{@attempt} for simple_retry step"

    # Fail the first 2 attempts to demonstrate retry
    if @attempt < 3
      raise Net::ReadTimeout, "Simulated timeout error"
    end

    "Success after #{@attempt} attempts!"
  end
end
