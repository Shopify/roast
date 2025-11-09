# typed: true
# frozen_string_literal: true

module Kernel
  #: -> self
  def not_nil!
    self
  end
end

class NilClass
  # @override
  #: -> bot
  def not_nil!
    raise UnexpectedNilError
  end
end

class UnexpectedNilError < StandardError
  def initialize(message = "Unexpected nil value encountered.")
    super(message)
  end
end
