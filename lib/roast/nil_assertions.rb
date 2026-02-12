# typed: true
# frozen_string_literal: true

module Kernel
  #: -> self
  def !
    self
  end
end

class NilClass
  # @override
  #: -> bot
  def !
    raise UnexpectedNilError
  end
end

class UnexpectedNilError < StandardError
  def initialize(message = "Unexpected nil value encountered.")
    super(message)
  end
end
