# Agent Steps in Roast

Agent steps provide a way to send prompts directly to a coding agent (like Claude Code) without going through the standard LLM translation layer. This document explains when and how to use agent steps effectively.

## What are Agent Steps?

Agent steps are denoted by prefixing a step name with `^`. They bypass the normal LLM processing and send your prompt content directly to the CodingAgent tool.

```yaml
steps:
  # File-based prompts
  - analyze_code       # Regular step - processed by LLM first
  - ^implement_fix     # Agent step - direct to CodingAgent
  
  # Inline prompts
  - Analyze the code quality and suggest improvements          # Regular inline
  - ^Fix all ESLint errors and apply Prettier formatting       # Agent inline
```

Both file-based prompts (with directories like `implement_fix/prompt.md`) and inline prompts (text with spaces) are supported.

## When to Use Agent Steps

### Use Agent Steps When:

1. **You need precise control over tool usage**
   - When you want to ensure specific tools are used in a particular way
   - When the task requires exact file manipulations or code transformations

2. **Complex multi-file operations**
   - When coordinating changes across multiple files
   - When the operation requires specific sequencing of edits

3. **Performance optimization**
   - When you want to skip the LLM interpretation layer
   - For well-defined tasks that don't need additional context

### Use Regular Steps When:

1. **You need natural language processing**
   - When the prompt benefits from LLM interpretation
   - When you want the LLM to add context or reasoning

2. **Flexible, adaptive responses**
   - When the exact approach might vary based on context
   - When you want the LLM to make judgment calls

## Practical Examples

### Example 1: Database Migration

**Regular Step (analyze_migration/prompt.md):**
```markdown
Look at the user's database schema and determine what migrations might be needed to support the new features they've described. Consider best practices for database design.
```

This benefits from LLM interpretation because:
- It needs to understand "best practices" in context
- It should make judgments about schema design
- The approach varies based on the specific features

**Agent Step (^apply_migration/prompt.md):**
```markdown
Create a new migration file with the following specifications:

1. Use MultiEdit to create file: db/migrate/{{timestamp}}_add_user_preferences.rb
2. The migration must include:
   - Add column :users, :preferences, :jsonb, default: {}
   - Add index :users, :preferences, using: :gin
   - Add column :users, :notification_settings, :jsonb, default: {}
3. Ensure proper up/down methods
4. Follow Rails migration conventions exactly

Required tools: MultiEdit
Do not use Write tool for migrations.
```

This is better as an agent step because:
- It requires specific tool usage (MultiEdit, not Write)
- The instructions are precise and technical
- No interpretation needed - just execution

### Example 2: Code Refactoring

**Regular Step (identify_code_smells/prompt.md):**
```markdown
Review the provided code and identify any code smells or anti-patterns. Consider things like:
- Long methods that do too much
- Duplicated code
- Poor naming
- Tight coupling
- Missing abstractions

Explain why each identified issue is problematic.
```

This works well as a regular step because it requires judgment and explanation.

**Agent Step (^extract_method/prompt.md):**
```markdown
Extract the authentication logic from UserController#create into a separate method:

1. Read file: app/controllers/user_controller.rb
2. Find the code block from line 15-28 (the authentication logic)
3. Create a new private method called `authenticate_user_params`
4. Move the authentication logic to this new method
5. Replace the original code with a call to the new method
6. Ensure all variables are properly passed

Use MultiEdit to make all changes in a single operation.
Preserve exact indentation and formatting.
```

This is ideal as an agent step because:
- Specific line numbers and method names
- Exact refactoring instructions
- No room for interpretation

### Example 3: Test Generation

**Regular Step (plan_test_coverage/prompt.md):**
```markdown
Analyze the {{file}} and determine what test cases would provide comprehensive coverage. Consider:
- Happy path scenarios
- Edge cases
- Error conditions
- Boundary values

Focus on behavior, not implementation details.
```

**Agent Step (^implement_tests/prompt.md):**
```markdown
Create test file: test/models/user_validator_test.rb

Implement exactly these test cases:
1. test "validates email format"
   - Use valid emails: ["user@example.com", "test.user+tag@domain.co.uk"]
   - Use invalid emails: ["invalid", "@example.com", "user@", "user space@example.com"]
   
2. test "validates age is positive integer"
   - Valid: [18, 25, 100]
   - Invalid: [-1, 0, 17, 101, "twenty", nil]

3. test "validates username uniqueness"
   - Create user with username "testuser"
   - Attempt to create second user with same username
   - Assert validation error on :username

Use minitest assertion style.
Each test must be independent.
Use setup method for common test data.
```

### Example 4: API Integration

**Regular Step (design_api_client/prompt.md):**
```markdown
Design a client for the {{api_name}} API that follows Ruby best practices. Consider:
- Error handling strategies
- Rate limiting
- Authentication patterns
- Response parsing
- Testing approach

Suggest an architecture that will be maintainable and extensible.
```

**Agent Step (^implement_api_client/prompt.md):**
```markdown
Implement the API client with this exact structure:

1. Create file: lib/external_apis/weather_api/client.rb
   ```ruby
   module ExternalApis
     module WeatherApi
       class Client
         include HTTParty
         base_uri 'https://api.weather.com/v1'
         
         def initialize(api_key)
           @api_key = api_key
           @options = { headers: { 'Authorization' => "Bearer #{api_key}" } }
         end
         
         def current_weather(location)
           response = self.class.get("/current", @options.merge(query: { location: location }))
           handle_response(response)
         end
         
         private
         
         def handle_response(response)
           raise ApiError, response.message unless response.success?
           response.parsed_response
         end
       end
     end
   end
   ```

2. Create file: lib/external_apis/weather_api/api_error.rb
   Define custom exception class

3. Update file: config/initializers/weather_api.rb
   Add configuration for API endpoint and timeout

Use exact module structure and method signatures shown.
```

## Best Practices

1. **Be explicit about tool usage in agent steps**
   ```markdown
   # Good agent step
   Use MultiEdit tool to update the following files:
   - app/models/user.rb: Add validation
   - test/models/user_test.rb: Add test case
   
   # Avoid in agent steps
   Update the user model with better validation
   ```

2. **Include specific line numbers or code markers when possible**
   ```markdown
   # Good agent step
   In app/controllers/application_controller.rb:
   - Find method `authenticate_user!` (around line 45)
   - Add the following before the redirect_to call:
     session[:return_to] = request.fullpath
   ```

3. **Specify exact formatting requirements**
   ```markdown
   # Good agent step
   Create method with exactly this signature:
   def calculate_tax(amount, rate = 0.08)
   
   Ensure:
   - Two-space indentation
   - No trailing whitespace
   - Blank line before method definition
   ```

4. **Chain agent steps for complex operations**
   ```yaml
   steps:
     # First understand the system
     - analyze_current_architecture
     
     # Then execute precise changes
     - ^create_service_objects
     - ^update_controllers  
     - ^add_test_coverage
     
     # Finally verify
     - verify_all_tests_pass
   ```

## Summary

Agent steps are powerful when you need direct control over tool usage and precise execution of technical tasks. They complement regular steps by handling the implementation details while regular steps handle the analysis and planning.

Choose agent steps when precision matters more than interpretation. Choose regular steps when context and judgment are important.