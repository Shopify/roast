# Document 10: Writing Custom Cogs

_The extensibility guide for contributors building new cog types._

---

## 1. The Custom Cog Contract

Every custom cog must satisfy a minimal contract to integrate with the Roast framework. The framework discovers, registers, configures, and executes cogs through standardized interfaces.

### Required Elements

| # | Requirement | Details |
|---|-------------|---------|
| 1 | **Named class** inheriting from `Roast::Cog` | Anonymous classes (`Class.new(Roast::Cog)`) have `name == nil`, which triggers `Cog::Registry::CouldNotDeriveCogNameError` at registration time (registry.rb line 63). |
| 2 | **Nested `Input` class** inheriting from `Cog::Input` | Must implement `validate!`. The base class's `validate!` raises `NotImplementedError` (input.rb line 35), so you **must** override it. Auto-discovered via `find_child_input_or_default` (cog.rb line 35). |
| 3 | **`execute(input)` method** | Protected method returning a `Cog::Output` instance (or subclass). The base class raises `NotImplementedError` (cog.rb line 143). |

### Optional Elements

| # | Element | Details |
|---|---------|---------|
| 4 | **Nested `Config` class** inheriting from `Cog::Config` | Auto-discovered via `find_child_config_or_default` (cog.rb line 30). Falls back to base `Cog::Config` (empty, no validation). |
| 5 | **Nested `Output` class** inheriting from `Cog::Output` | **NOT auto-discovered** — unlike Config and Input, there is no `find_child_output_or_default`. Your `execute` method constructs and returns the Output directly. |

### The Auto-Discovery Asymmetry

This is a critical design point that trips people up:

```
                Auto-Discovered?     Who Creates It?
Config          ✅ Yes               Framework (ConfigManager)
Input           ✅ Yes               Framework (Cog#run!, line 78)
Output          ❌ No                Your code (execute method)
```

**Why the asymmetry?** Config and Input are constructed by framework machinery before your code runs. The framework needs to find the right class to instantiate. Output is constructed by your `execute` method — you're already running, you know what to return.

The auto-discovery mechanism uses `const_defined?` and `const_get` on the string `"#{cog_class.name}::Config"` (or `::Input`). The nested class must be defined **inside** your cog class to be found.

---

## 2. Config: The `@values` Hash Contract

### The Golden Rule

**ALL configuration values MUST be stored in `@values`.** This is not a suggestion — the merge cascade depends on it.

The `merge` method (config.rb line 47):

```ruby
def merge(config_object)
  self.class.new(values.merge(config_object.values))
end
```

If you store a value in `@temperature` instead of `@values[:temperature]`, it will be **silently lost** when ConfigManager runs the 4-layer cascade (global → general → regexp → name-specific). Only `@values` survives the merge.

### The `field` Macro

For simple get/set fields with defaults, use the `field` class method (config.rb line 110):

```ruby
class Config < Roast::Cog::Config
  field :temperature, 0.7
  field :model, "gpt-4o-mini" do |value|
    raise InvalidConfigError, "model must be a string" unless value.is_a?(String)
    value  # validator return value becomes the stored value
  end
end
```

This generates two methods:

1. **`temperature(*args)`** — Getter (no args) or setter (with arg)
2. **`use_default_temperature!`** — Explicitly resets to default

#### ⚠️ The Falsy Value Pitfall

The getter implementation (config.rb line 116):

```ruby
@values[key] || default.deep_dup
```

This means:
- If `@values[:enabled] = false`, then `false || default` returns **the default**, not `false`
- If `@values[:enabled] = nil`, same problem
- `0` also triggers this (`0` is falsy in Ruby? No — `0` is truthy in Ruby, but this is still fragile thinking)

**Actually**: Only `false` and `nil` are falsy in Ruby. So the pitfall affects:
- Boolean fields where `false` is a legitimate set value
- Fields where `nil` means "explicitly set to nil" vs "not configured"

#### Workaround for Boolean Fields

Don't use `field`. Use the imperative toggle pattern (same as base `Cog::Config` does for `async!` and `abort_on_failure!`):

```ruby
def enable!
  @values[:enabled] = true
end

def disable!
  @values[:enabled] = false
end

def enabled?
  !!@values[:enabled]
end
```

Or for "default true" booleans (like `abort_on_failure?`):

```ruby
def enabled?
  @values.fetch(:enabled, true)
end
```

### The `validate!` Method on Config

`validate!` on Config is called **after** the merge cascade completes — i.e., on the fully-merged config object. This means:
- Your validation sees the final resolved values from all 4 layers
- You can validate combinations ("if provider is :claude, model must be specified")
- The base implementation is a no-op (config.rb line 25) — override only if needed

### Hash-Style Access

For simple cases where `field` is too rigid, Config supports direct hash syntax:

```ruby
config[:my_key] = "value"    # []= calls @values[key] = value
config[:my_key]              # [] calls @values[key]
```

---

## 3. Input: The validate!/coerce Lifecycle

### The Two-Phase Pattern

The input lifecycle (executed in `Cog#run!`, lines 78–82):

```
1. Create Input instance (no-arg constructor)
2. Run input block via instance_exec (user code sets fields on Input + any other prep work)
3. Call validate!
   ├── If passes: proceed to execute
   └── If raises InvalidInputError:
       4. Call coerce(return_value_from_input_block)
       5. Call validate! again (mandatory — must pass or workflow crashes)
```

This is implemented in `coerce_and_validate_input!` (cog.rb line 149):

```ruby
def coerce_and_validate_input!(input, return_value)
  input.validate!
rescue Cog::Input::InvalidInputError
  input.coerce(return_value)
  input.validate!
end
```

### Implementing `validate!`

The base class raises `NotImplementedError` — you **must** override. Your implementation should:

```ruby
def validate!
  raise InvalidInputError, "prompt is required" if prompt.nil? && !coerce_ran?
end
```

Key pattern: Use `coerce_ran?` to distinguish between the first validation (optimistic — can fail to trigger coercion) and the second validation (final — must accept the coerced state).

**Why this matters**: Some inputs have fields that can legitimately be `nil` after coercion. Without `coerce_ran?`, the second `validate!` call would reject a valid nil.

### Implementing `coerce`

`coerce` is optional. The base implementation just sets `@coerce_ran = true` (input.rb line 49):

```ruby
def coerce(input_return_value)
  @coerce_ran = true
end
```

If you override it, **always call `super`** to maintain the `coerce_ran?` flag:

```ruby
def coerce(input_return_value)
  super  # Sets @coerce_ran = true
  @prompt = input_return_value.to_s if input_return_value
end
```

**What is `input_return_value`?** It's the return value from the user's input block:

```ruby
chat(:analyze) { "What is the meaning of life?" }
#                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ this string is input_return_value
```

Standard cogs use coercion as a convenience mechanism:
- **cmd**: String → `command`, Array → first=`command` + rest=`args`
- **chat**: String → `prompt`
- **agent**: String → `[prompt]`, Array → `prompts`
- **ruby**: anything → `value`

### The `coerce_ran?` Helper

Private method (input.rb line 67). Returns `false` until `coerce` is called (which sets `@coerce_ran = true`). Used exclusively by `validate!` to determine whether this is the first or second validation pass.

---

## 4. Output: Mixins and `raw_text`

### The Output Base Class

`Cog::Output` is minimal — it has no attrs, no constructor args, and just a private `raw_text` that raises `NotImplementedError` (output.rb line 308). Your custom Output adds whatever fields are appropriate:

```ruby
class Output < Roast::Cog::Output
  attr_reader :result, :metadata

  def initialize(result, metadata)
    super()  # IMPORTANT: call with empty parens (base has no-arg constructor)
    @result = result
    @metadata = metadata
  end
end
```

### Including Mixin Modules

Three optional modules provide parsing convenience methods:

| Module | Methods | Requires |
|--------|---------|----------|
| `WithText` | `text`, `lines` | `raw_text` → String |
| `WithJson` | `json`, `json!` | `raw_text` → String? |
| `WithNumber` | `float`, `float!`, `integer`, `integer!` | `raw_text` → String? |

To use them:

```ruby
class Output < Roast::Cog::Output
  include WithText
  include WithJson
  include WithNumber

  attr_reader :response

  def initialize(response)
    super()
    @response = response
  end

  private

  def raw_text
    @response
  end
end
```

### The `raw_text` Contract

All three modules call `raw_text` to get the source string for parsing. It's defined as a private method in the base Output class (raises `NotImplementedError`). If you include ANY mixin, you must implement `raw_text`.

**Important**: The base `Output` class defines `raw_text` at line 308. Each mixin also declares it (e.g., `WithText` at line 297, `WithJson` at line 48). Ruby's method resolution means the **last include wins** for the abstract declaration, but since they all delegate to the same private method you define, this is fine in practice. Just implement one `raw_text` in your Output class.

### JSON Candidate Priority

`WithJson` uses a sophisticated multi-strategy extraction (output.rb lines 68–76):

1. Entire input string (stripped)
2. ` ```json ` code blocks (**last first**)
3. ` ``` ` code blocks with no language (**last first**)
4. ` ```type ` code blocks with any other language (**last first**)
5. `{ }` or `[ ]` patterns (**longest first**)

The "last first" strategy exists because LLMs often put their final answer at the end. The method tries each candidate with `JSON.parse` and returns the first that succeeds.

### Number Candidate Priority

`WithNumber` uses bottom-up scanning (output.rb lines 230–249):

1. Entire input (stripped)
2. Each line from **bottom up** (stripped, empty lines removed)
3. Number patterns extracted from each line (bottom up, regex: `/-?[\d\s$¢£€¥.,_]+(?:[eE][+-]?\d+)?/`)

Normalization strips `$¢£€¥,_` and whitespace, then validates the result matches `/\A-?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?\z/`.

---

## 5. Loading Custom Cogs

### The `use` Directive

`use` is called at the top level of a workflow file, and runs during `extract_dsl_procs!` (workflow.rb line 134) — **before** `prepare!`. This ensures custom cogs are registered and bound alongside built-in cogs.

### Local Loading (no `from:`)

```ruby
use "local"
```

Resolution path:
```
workflow_path.realdirpath.dirname.join("cogs/local").to_s
```

So if your workflow is at `/app/workflows/my_flow.rb`, the cog must be at `/app/workflows/cogs/local.rb`.

**Constraints**:
- The directory is always `cogs/` — not configurable
- The file must define the class at the top level (or use the full class name in `use`)

### Gem Loading (with `from:`)

```ruby
use "simple", from: "plugin_gem_example"
```

Steps (workflow.rb lines 106–125):
1. `require "plugin_gem_example"` — loads the gem's entry point
2. `"simple".camelize` → `"Simple"`
3. `Object.const_defined?("Simple")` — check existence
4. `"Simple".constantize` → resolves to the class
5. `Simple < Roast::Cog` — validate inheritance
6. `@cog_registry.use(Simple)` — register

### Multi-Name Loading

```ruby
use "simple", "MyCogNamespace::Other", from: "plugin_gem_example"
```

The gem is `require`d **once**. Each name is resolved and registered separately. This is efficient for gems that provide multiple cog types.

### Name Derivation Algorithm

`Cog::Registry#create_registration` (registry.rb line 65):

```ruby
cog_class_name.demodulize.underscore.to_sym
```

Examples:
- `Simple` → `:simple`
- `MyCogNamespace::Other` → `:other`
- `MyCogs::MyCustomCog` → `:my_custom_cog`
- `Roast::Cogs::Chat` → `:chat`

**Critical implication**: `demodulize` drops ALL namespacing. Two classes `A::Widget` and `B::Widget` both derive to `:widget`. Last `use` call wins (overwrites silently).

### Overwrite Behavior

`Registry#use` overwrites existing registrations without error (registry.rb line 55):

```ruby
def use(cog_class)
  name, klass = create_registration(cog_class)
  cogs[name] = klass  # Simple hash assignment — overwrites
end
```

This is by design:
- A gem can override a built-in (register a custom `:cmd` that replaces the standard one)
- The test suite explicitly validates this behavior

### Name Collision With Ruby Methods

The name collision check happens **at bind time** (during `prepare!`), not during `use`:

```ruby
# config_manager.rb line 92
raise IllegalCogNameError, cog_method_name if respond_to?(cog_method_name, true)

# execution_manager.rb line 193
raise IllegalCogNameError, cog_method_name if respond_to?(cog_method_name, true)
```

The `true` argument to `respond_to?` includes private methods. This catches names like `:freeze`, `:hash`, `:class`, `:object_id`, etc.

**Consequence**: You can `use` a cog named `:freeze` without error — it only fails when `prepare!` tries to bind it to the contexts. The error is `ConfigManager::IllegalCogNameError` or `ExecutionManager::IllegalCogNameError` (two separate, unrelated classes with the same base name).

---

## 6. The Plugin Gem Pattern

### Minimal Gem Structure

```
my-cog-gem/
├── lib/
│   ├── my_cog_gem.rb        # Entry point (require'd by `use ... from:`)
│   └── my_widget.rb         # class MyWidget < Roast::Cog
├── my-cog-gem.gemspec
└── Gemfile
```

### Entry Point (`lib/my_cog_gem.rb`)

Must make the cog class available in the global namespace:

```ruby
# frozen_string_literal: true

require "my_widget"
```

That's it. No special registration, no plugin API. The `use` directive handles registration after the `require`.

### Gemspec

Add `roast-ai` as a dependency:

```ruby
Gem::Specification.new do |spec|
  spec.name = "my-cog-gem"
  # ...
  spec.add_dependency("roast-ai")
end
```

### Workflow Usage

```ruby
use "my_widget", from: "my_cog_gem"

config do
  my_widget { temperature 0.5 }
end

execute do
  my_widget(:thing) { |my| my.value = "hello" }
end
```

### Multiple Cogs Per Gem

```ruby
# lib/my_cog_gem.rb
require "my_widget"
require "my_other_cog"

# workflow.rb
use "my_widget", "my_other_cog", from: "my_cog_gem"
```

### Namespaced Cogs

```ruby
# lib/other.rb
module MyCogNamespace
  class Other < Roast::Cog
    class Input < Roast::Cog::Input
      def validate!; end
    end

    def execute(input)
      # ...
    end
  end
end

# workflow.rb — use the full class name string:
use "MyCogNamespace::Other", from: "my_cog_gem"
# DSL name becomes: :other (demodulized + underscored)
```

---

## 7. Complete Custom Cog Example

Here's a fully-realized custom cog demonstrating all contract points:

```ruby
# typed: true
# frozen_string_literal: true

class HttpFetch < Roast::Cog
  class Config < Roast::Cog::Config
    field :timeout, 30 do |value|
      raise InvalidConfigError, "timeout must be positive" unless value.is_a?(Integer) && value > 0
      value
    end

    def follow_redirects!
      @values[:follow_redirects] = true
    end

    def no_follow_redirects!
      @values[:follow_redirects] = false
    end

    def follow_redirects?
      @values.fetch(:follow_redirects, true)
    end

    def validate!
      # Called after the full merge cascade
    end
  end

  class Input < Roast::Cog::Input
    attr_accessor :url, :method_name, :headers

    def validate!
      raise InvalidInputError, "url is required" if url.nil? && !coerce_ran?
    end

    def coerce(input_return_value)
      super  # Sets @coerce_ran = true
      case input_return_value
      when String
        @url = input_return_value
      when Hash
        @url = input_return_value[:url]
        @method_name = input_return_value[:method]
        @headers = input_return_value[:headers]
      end
    end
  end

  class Output < Roast::Cog::Output
    include WithText
    include WithJson
    include WithNumber

    attr_reader :body, :status_code, :response_headers

    def initialize(body, status_code, response_headers)
      super()
      @body = body
      @status_code = status_code
      @response_headers = response_headers
    end

    private

    def raw_text
      @body
    end
  end

  protected

  def execute(input)
    # @config is set by the framework before execute runs
    # Use @config to access merged configuration
    response = perform_request(
      url: input.url,
      method: input.method_name || :get,
      headers: input.headers || {},
      timeout: @config.timeout,
      follow_redirects: @config.follow_redirects?
    )
    Output.new(response.body, response.status, response.headers)
  end

  private

  def perform_request(url:, method:, headers:, timeout:, follow_redirects:)
    # Implementation here
  end
end
```

Usage in a workflow:

```ruby
use "http_fetch"  # Loads from cogs/http_fetch.rb

config do
  http_fetch { timeout 60 }
  http_fetch(:api_call) { no_follow_redirects! }
end

execute do
  http_fetch(:api_call) { "https://api.example.com/data" }
  ruby(:result) { |my| my.value = http_fetch!(:api_call).json }
end
```

---

## 8. Testing Custom Cogs

### The `run_cog` Helper

Defined in `test/test_helper.rb` (line 117), this provides the complete async execution harness:

```ruby
def run_cog(cog, config: nil, scope_value: nil, scope_index: 0)
  config ||= cog.class.config_class.new

  Sync do
    barrier = Async::Barrier.new
    input_context = Roast::CogInputContext.new
    Fiber[:path] = [Roast::TaskContext::PathElement.new(execution_manager: mock_execution_manager)]

    cog.run!(barrier, config, input_context, scope_value, scope_index)
    barrier.wait
  end

  cog
end
```

This sets up:
- An `Async::Barrier` (for the cooperative scheduling)
- A bare `CogInputContext` (no cog accessors bound — just control flow)
- A mock `TaskContext` path element (for event attribution)
- Runs the full `cog.run!` lifecycle and waits for completion

### Writing Tests for a Custom Cog

```ruby
require "test_helper"
require_relative "../path/to/http_fetch"

class HttpFetchTest < ActiveSupport::TestCase
  setup do
    input_proc = proc { |my| my.url = "https://example.com" }
    @cog = HttpFetch.new(:test_fetch, input_proc)
  end

  test "successful fetch returns output with body" do
    # Stub your external dependency
    HttpFetch.any_instance.stubs(:perform_request).returns(
      OpenStruct.new(body: '{"key":"value"}', status: 200, headers: {})
    )

    run_cog(@cog)

    assert @cog.succeeded?
    assert_equal 200, @cog.output.status_code
    assert_equal({ key: "value" }, @cog.output.json)
  end

  test "config cascade applies" do
    config = HttpFetch::Config.new
    config.timeout(60)
    config.no_follow_redirects!

    HttpFetch.any_instance.stubs(:perform_request).returns(
      OpenStruct.new(body: "ok", status: 200, headers: {})
    )

    run_cog(@cog, config: config)

    assert @cog.succeeded?
  end

  test "missing url fails validation" do
    empty_proc = proc { }
    cog = HttpFetch.new(:fail_fetch, empty_proc)

    assert_raises(Roast::Cog::Input::InvalidInputError) do
      run_cog(cog)
    end
  end
end
```

### The TestCog Reference Implementation

`test/support/test_cog.rb` provides the canonical minimal custom cog used across the test suite:

```ruby
module TestCogSupport
  class TestInput < Roast::Cog::Input
    attr_accessor :value

    def validate!
      raise InvalidInputError if value.nil? && !coerce_ran?
    end

    def coerce(input_return_value)
      super
      @value = input_return_value
    end
  end

  class TestOutput < Roast::Cog::Output
    attr_reader :value

    def initialize(value)
      super()
      @value = value
    end
  end

  class TestCog < Roast::Cog
    class Config < Roast::Cog::Config; end
    class Input < TestInput; end

    def execute(input)
      TestOutput.new(input.value)
    end
  end
end
```

Key patterns to copy:
- `validate!` uses `coerce_ran?` — strict first, lenient after coercion
- `coerce` calls `super` — maintains the `coerce_ran?` flag
- `Output#initialize` calls `super()` — empty parens (base has no-arg constructor)
- `execute` returns an Output instance — never a raw value

---

## 9. Gotchas and Edge Cases

### 1. execute Must Return an Output (or nil)

The framework stores whatever `execute` returns in `@output` (cog.rb line 83). If you return `nil`, `succeeded?` returns `false` (because it checks `@output != nil`). No error is raised — the cog just appears to have not completed.

If you return something that isn't a `Cog::Output`, things will work until someone calls a method on the output that doesn't exist (like `.text` or `.json`), at which point you get a `NoMethodError`.

### 2. Config Values Lost Outside @values

```ruby
# WRONG — value lost during merge cascade
class Config < Roast::Cog::Config
  attr_accessor :temperature
end

# RIGHT — value preserved during merge
class Config < Roast::Cog::Config
  field :temperature, 0.7
end

# ALSO RIGHT — manual @values storage
class Config < Roast::Cog::Config
  def temperature(value = :_no_arg_)
    if value == :_no_arg_
      @values[:temperature] || 0.7
    else
      @values[:temperature] = value
    end
  end
end
```

### 3. Anonymous Classes Crash

```ruby
# This raises CouldNotDeriveCogNameError
klass = Class.new(Roast::Cog)
registry.use(klass)  # Error! klass.name is nil
```

Always use named classes.

### 4. Namespace Collision Is Silent

```ruby
use "namespace_a/widget", from: "gem_a"  # registers as :widget
use "namespace_b/widget", from: "gem_b"  # OVERWRITES :widget — no warning
```

The last `use` wins. There is no duplicate detection or warning.

### 5. Reserved Names

Any name that would collide with an existing method on `ConfigContext` or `ExecutionContext` will fail at bind time. Reserved names include all Object instance methods: `freeze`, `hash`, `class`, `object_id`, `send`, `dup`, `clone`, `nil?`, `tap`, `then`, `is_a?`, etc.

Additionally, `global`, `outputs`, and `outputs!` are pre-bound by the managers.

### 6. The `validate!` Returning `true` Pattern

You'll see this in simple examples:

```ruby
def validate!
  true
end
```

This is valid — it means "all inputs are always valid, never trigger coercion." The framework only cares about whether `validate!` raises, not its return value.

### 7. Output Mixin Memoization

Both `WithJson` and `WithNumber` memoize their results:

```ruby
@json ||= parse_json_with_fallbacks(input)
@float ||= parse_number_with_fallbacks(raw_text || "")
```

This means calling `.json` multiple times returns the same parsed result. But it also means if `raw_text` changes after first access (unlikely but possible), the cached value is stale.

### 8. The `@config` Variable

In `Cog#run!` (line 77), `@config = config` overwrites the default config created in the constructor (line 57). Your `execute` method always sees the fully-merged config. You never need to merge configs yourself — the framework has already done it.

---

## 10. Checklist for Contributors

When creating a new custom cog, verify:

- [ ] Class has a proper name (not anonymous)
- [ ] Class inherits from `Roast::Cog`
- [ ] `Input` class is nested inside the cog class (for auto-discovery)
- [ ] `Input#validate!` is implemented (raises `InvalidInputError` on failure)
- [ ] `Input#coerce` calls `super` if overridden
- [ ] `Config` class stores all values in `@values` (not instance variables)
- [ ] `Config` class is nested inside the cog class (for auto-discovery)
- [ ] `Output#initialize` calls `super()` with empty parens
- [ ] `Output` implements `raw_text` if any mixin is included
- [ ] `execute` returns an Output instance (not `nil`, not a raw value)
- [ ] DSL name doesn't collide with Object methods or other registered cogs
- [ ] If using namespaces, you understand that only the demodulized name is used in the DSL

---

## See Also

- [01 Architecture Overview](01-architecture-overview.md) — The three evaluation contexts and cog lifecycle
- [03 Cog Reference](03-cog-reference.md) — Complete reference for all built-in cogs (as implementation examples)
- [05 Execution Engine Internals](05-execution-engine-internals.md) — How ConfigManager and ExecutionManager bind and run cogs
- [06 Metaprogramming Map](06-metaprogramming-map.md) — How `define_singleton_method` binds cog methods to contexts
- [12 Known Issues & Gotchas](12-known-issues-and-gotchas.md) — The falsy value pitfall and other fragilities
