#!/usr/bin/env ruby

class Calculator
  def add(a, b)
    a + b
  end

  def subtract(a, b)
    a - b
  end

  def multiply(a, b)
    a * b
  end

  def divide(a, b)
    raise ArgumentError, "Cannot divide by zero" if b == 0
    a.to_f / b
  end

  def power(a, b)
    a ** b
  end

  def factorial(n)
    raise ArgumentError, "Factorial is only defined for non-negative integers" if n < 0 || !n.is_a?(Integer)
    return 1 if n == 0
    (1..n).reduce(:*)
  end

  def fibonacci(n)
    raise ArgumentError, "Fibonacci is only defined for non-negative integers" if n < 0 || !n.is_a?(Integer)
    return 0 if n == 0
    return 1 if n == 1

    a, b = 0, 1
    (n - 1).times do
      a, b = b, a + b
    end
    b
  end

  def is_prime?(n)
    return false if n < 2 || !n.is_a?(Integer)
    return true if n == 2
    return false if n.even?

    limit = Math.sqrt(n).to_i
    (3..limit).step(2) do |i|
      return false if n % i == 0
    end
    true
  end
end
