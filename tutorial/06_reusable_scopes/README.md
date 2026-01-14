# Chapter 6: Reusable Scopes

In previous chapters, all your workflows used a single `execute` block. Now you'll learn how to create reusable scopes
that can be called multiple times with different inputs, making your workflows more modular and maintainable.

## What You'll Learn

- How to define named execute scopes
- How to call scopes with the `call` cog
- How to pass values to scopes
- How to return values from scopes with `outputs!`
- How to extract outputs using `from()`

## Named Execute Scopes

Define a named execute scope by providing a name to `execute`. Just like the top-level execute scope, you can define
however many steps you want, and they'll run in order, top-to-bottom. Cogs can access the outputs of previous
cog's in their own scope, but cannot access the output of cogs defined in other scopes.

```ruby
execute(:process_file) do
  cmd(:word_count) { "wc -w #{filename}" }
  ruby { puts "Words: #{cmd!(:word_count).text}" }
end
```
You define all execute scopes at the top level of your workflow file. But, you can define them in any order. 
Named scopes don't run automatically. They must be called explicitly using a cog like the `call` cog.

## The call Cog

Use the `call` cog to invoke a named scope:

```ruby
execute(:greet) do
  chat { "say 'Hello, World!'" }
  chat { "Tell me a funny joke" }
end

execute do
  call(run: :greet)  # Invokes the :greet scope
end
```

You can call the same scope multiple times:

```ruby
execute do
  call(run: :greet)
  call(run: :greet)
  call(run: :greet)
end
```

## Passing Values to Scopes

Pass values to a called scope, and access them as the second block parameter in any cog's input block:

```ruby
execute(:greet_person) do
  chat do |my, name|
    my.prompt = "Say hello to #{name}!"
  end
end

execute do
  call(run: :greet_person) { "Alice" }
  call(run: :greet_person) { "Bob" }
end
```

The value from the `call` cog becomes available as the second parameter to any cog in the called scope.

## Returning Values with outputs!

Use `outputs!` to specify what a scope returns:

```ruby
execute(:double_number) do
  ruby(:calculate) { |_, number| number * 2 }

  outputs! { ruby!(:calculate).value }
end

execute do
  call(:result, run: :double_number) { 21 }

  ruby do
    answer = from(call!(:result))
    puts "The answer is: #{answer}"  # => 42
  end
end
```

The `from()` helper extracts the final output from a called scope.

## Extracting output values from specific cogs

The `outputs!` block is optional. In its absence, the return value will be the output value of the final cog
in the scope. You can also pass a block to `from` and access the output of any cog(s) you want from the scope.

```ruby
execute(:number_math) do
  ruby(:add_two) { |_, number| number + 2 }
  ruby(:subtract_two) { |_, number| number - 2 }
  ruby(:multiply_by_two) { |_, number| number * 2 }
  ruby(:divide_by_two) { |_, number| number / 2 }
end

execute do
  # the return value of the block given to `call` will be the value passed to the scope being run,
  # but you can also set the value explicitly
  call(:result, run: :number_math) { |my| my.value = 28 }

  ruby do
    answer = from(call!(:result)).value # this yields the output of the final cog in :number_math: ruby!(:divide_by_two)
    puts "The final answer is: #{answer}"  # => 14
    
    # pass a block to `from` to access the output of other cogs from the scope that was run
    # this block runs in the context of the other scope and can access any cogs defined in it
    subtraction, multiplication = from(call!(:result)) do
      [
        ruby!(:subtract_two).value,
        ruby!(:multiply_by_two).value
      ]
    end
    puts "Some intermediate answers are: #{subtraction} (subtraction) and #{multiplication} (multiplication)"
  end
end
```

## Running the Workflows

To run the examples in this chapter:

```bash
# Basic scope example
bin/roast execute tutorial/06_reusable_scopes/basic_scope.rb
```

```bash
# Parameterized scope example
bin/roast execute tutorial/06_reusable_scopes/parameterized_scope.rb
```

```bash
# Accessing specific scope outputs
bin/roast execute tutorial/06_reusable_scopes/accessing_scope_outputs.rb
```

## Try It Yourself

1. **Create reusable logic** - Extract common operations into named scopes
2. **Parameterize scopes** - Pass different values to the same scope
3. **Return values** - Use `outputs!` to capture 'default' result values from scopes
4. **Chain scopes** - Call scopes from within other scopes

## Key Takeaways

- Use `execute(:name) do ... end` to define reusable scopes
- Use `call(run: :scope_name)` to invoke named scopes
- Pass values to scopes using the block parameter of `call`
- Access passed values as the second parameter in cog input blocks
- Use `outputs!` to specify what a scope returns
- Use `from(call!(:name))` to extract the return value
- Named scopes don't run unless explicitly called

## What's Next?

In the next chapter, you'll learn about `map`—a powerful way to apply a scope to every item in a collection, enabling
batch processing and parallel execution.

But first, experiment with reusable scopes to make your workflows more modular!
