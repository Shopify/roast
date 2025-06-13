# frozen_string_literal: true
# typed: false

module RedefineConstants
  def redefine_constant(mod, constant, new_value)
    @redefined_constants ||= []
    @redefined_constants << [mod, constant, mod.const_get(constant)]
    ignore_constant_redefined_warnings do
      mod.const_set(constant, new_value)
    end
  end

  def with_redefined_constant(mod, constant, new_value)
    redefine_constant(mod, constant, new_value)
    yield
  ensure
    @redefined_constants.reject! do |xmod, xconstant, old_value|
      next(false) unless mod == xmod && constant == xconstant

      ignore_constant_redefined_warnings do
        mod.const_set(constant, old_value)
      end
      true
    end
  end

  def reset_constants
    return unless @redefined_constants

    @redefined_constants.each do |mod, constant, old_value|
      ignore_constant_redefined_warnings do
        mod.const_set(constant, old_value)
      end
    end

    @redefine_constants = nil
  end

  def ignore_constant_redefined_warnings
    warn_level = $VERBOSE
    $VERBOSE = nil
    yield
    $VERBOSE = warn_level
  end

  def teardown
    reset_constants
    super
  end
end
