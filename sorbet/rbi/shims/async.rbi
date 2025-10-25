# typed: strong
#
# Type definitions for the Async gem
#

module Kernel
  # Creates an asynchronous task using fibers
  sig { params(block: T.proc.returns(T.untyped)).returns(T.untyped) }
  def Async(&block); end
end
