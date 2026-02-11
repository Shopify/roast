Write tests for classes that do not have test coverage.

## Arguments

Accepts either:
- A file path, like `lib/roast/cog_input_context.rb`
- A class name, like `Roast::CogInputContext`

## Task

1. **Locate the source file:**
   - If given a class name, find the corresponding file in `lib/`
   - Read the source file to understand the class's behavior

2. **Check for existing tests:**
   - Search `test/` for existing test files for this class
   - If tests exist, identify gaps in coverage

3. **Study project test patterns:**
   - Look at similar test files in `test/roast/` to understand conventions
   - Note the test framework (ActiveSupport::TestCase) and assertion styles

4. **Write the tests:**
   - Create the test file at the appropriate location (e.g., `test/roast/<filename>_test.rb`)
   - Test only behavior defined in the class itself, not inherited behavior
   - Test each public method with representative cases
   - Test edge cases (nil arguments, error conditions, etc.)

5. **Run the tests:**
   - Execute the test file to verify all tests pass
   - Fix any failures before completing

## Important Constraints

- **Avoid mocking direct dependencies** - use real instances where possible
- **Simple mocks are acceptable for second-order dependencies** (dependencies of dependencies)
- **Do not test inherited behavior** - only test methods defined in the class itself
- **Do not test type signatures** - Sorbet handles type checking, so don't test that methods return the correct type (e.g., `assert_instance_of String, @context.tmpdir`)
- **Do not test class hierarchies** - Don't test inheritance relationships like "InputError is a subclass of Roast::Error". These are not useful tests.
- **Do not test simple data classes** - Classes that only have `attr_reader`/`attr_accessor` and an initializer don't need tests unless they have complex initialization logic
- **Follow existing test conventions** in the project

## Test Helpers

### `TestCogSupport` (from `test/support/test_cog.rb`)

Shared test cog infrastructure. Use this when you need a generic cog for integration testing instead of defining your own. Provides:

- `TestCogSupport::TestInput` - A `Cog::Input` with `value` accessor, validation, and coercion
- `TestCogSupport::TestOutput` - A `Cog::Output` with a `value` reader
- `TestCogSupport::TestCog` - A `Cog` subclass that executes input into output, with its own `Config` and `Input` classes

Use these directly or alias them in your test class:

```ruby
class MyTest < ActiveSupport::TestCase
  # For integration tests that need a cog registered in a Registry:
  def setup
    @registry = Cog::Registry.new
    @registry.use(TestCogSupport::TestCog)
  end

  # For SystemCog subclasses that need a concrete Input:
  class TestSystemCog < SystemCog
    class Input < TestCogSupport::TestInput; end
  end
end
```

Only define a custom test cog when the class under test requires specific Config fields (e.g., `field :timeout, 30`) that `Cog::Config` doesn't provide.

### `run_cog(cog, config: nil, scope_value: nil, scope_index: 0)`

Run a cog through the full async execution path for integration testing. Use this when testing cog execution rather than testing individual Input/Output/Config classes in isolation.

```ruby
test "cog executes and returns expected output" do
  cog = MyCog.new(:test_cog, ->(_input, _scope, _index) { "some value" })

  run_cog(cog)

  assert cog.succeeded?
  assert_equal "expected", cog.output.value
end
```

Parameters:
- `cog` - The cog instance to run
- `config:` - Optional config (defaults to cog's config class)
- `scope_value:` - Optional executor scope value passed to input proc
- `scope_index:` - Optional executor scope index passed to input proc

## Style Rules

- Do NOT use `%w[]` word arrays — use `["a", "b"]` bracket style
- Do NOT add section comments (e.g., `# --- Config ---`) in test files
- Use `class << self` for class method definitions, not `def self.method_name`
- Use Ruby 1.9 hash syntax (`key:` not `:key =>`)

## Test File Structure

```ruby
# frozen_string_literal: true

require "test_helper"

module Roast
  class <ClassName>Test < ActiveSupport::TestCase
    def setup
      # Create instance and any required fixtures
    end

    def teardown
      # Clean up temporary resources if needed
    end

    test "method_name does expected behavior" do
      # Arrange, Act, Assert
    end
  end
end
```

## Immediate Instructions

Write tests for: $ARGUMENTS
