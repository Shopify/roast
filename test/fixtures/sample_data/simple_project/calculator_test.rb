#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative 'calculator'

class CalculatorTest < Minitest::Test
  def setup
    @calculator = Calculator.new
  end

  def test_addition
    assert_equal 8, @calculator.add(5, 3)
    assert_equal 0, @calculator.add(-5, 5)
    assert_equal -10, @calculator.add(-5, -5)
    assert_equal 3.5, @calculator.add(1.5, 2)
  end

  def test_subtraction
    assert_equal 2, @calculator.subtract(5, 3)
    assert_equal -10, @calculator.subtract(-5, 5)
    assert_equal 0, @calculator.subtract(5, 5)
    assert_equal 2.5, @calculator.subtract(5, 2.5)
  end

  def test_multiplication
    assert_equal 15, @calculator.multiply(5, 3)
    assert_equal -25, @calculator.multiply(-5, 5)
    assert_equal 0, @calculator.multiply(0, 100)
    assert_equal 7.5, @calculator.multiply(2.5, 3)
  end

  def test_division
    assert_equal 5.0, @calculator.divide(15, 3)
    assert_equal -2.0, @calculator.divide(-10, 5)
    assert_equal 2.5, @calculator.divide(5, 2)
    assert_equal 0.5, @calculator.divide(1, 2)
  end

  def test_division_by_zero
    assert_raises(ArgumentError) { @calculator.divide(10, 0) }
  end

  def test_power
    assert_equal 8, @calculator.power(2, 3)
    assert_equal 1, @calculator.power(5, 0)
    assert_equal 0.25, @calculator.power(2, -2)
    assert_equal 100, @calculator.power(10, 2)
  end

  def test_factorial
    assert_equal 1, @calculator.factorial(0)
    assert_equal 1, @calculator.factorial(1)
    assert_equal 120, @calculator.factorial(5)
    assert_equal 3628800, @calculator.factorial(10)
  end

  def test_factorial_with_negative_number
    assert_raises(ArgumentError) { @calculator.factorial(-1) }
  end

  def test_factorial_with_non_integer
    assert_raises(ArgumentError) { @calculator.factorial(3.5) }
  end

  def test_fibonacci
    assert_equal 0, @calculator.fibonacci(0)
    assert_equal 1, @calculator.fibonacci(1)
    assert_equal 1, @calculator.fibonacci(2)
    assert_equal 2, @calculator.fibonacci(3)
    assert_equal 3, @calculator.fibonacci(4)
    assert_equal 5, @calculator.fibonacci(5)
    assert_equal 55, @calculator.fibonacci(10)
  end

  def test_fibonacci_with_negative_number
    assert_raises(ArgumentError) { @calculator.fibonacci(-1) }
  end

  def test_fibonacci_with_non_integer
    assert_raises(ArgumentError) { @calculator.fibonacci(3.5) }
  end

  def test_is_prime
    assert_equal false, @calculator.is_prime?(0)
    assert_equal false, @calculator.is_prime?(1)
    assert_equal true, @calculator.is_prime?(2)
    assert_equal true, @calculator.is_prime?(3)
    assert_equal false, @calculator.is_prime?(4)
    assert_equal true, @calculator.is_prime?(5)
    assert_equal false, @calculator.is_prime?(10)
    assert_equal true, @calculator.is_prime?(17)
    assert_equal true, @calculator.is_prime?(23)
    assert_equal false, @calculator.is_prime?(100)
  end

  def test_is_prime_with_negative_number
    assert_equal false, @calculator.is_prime?(-5)
  end

  def test_is_prime_with_non_integer
    assert_equal false, @calculator.is_prime?(3.5)
  end
end