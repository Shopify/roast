# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About the codebase
- This is a Ruby gem called Roast. Its purpose is to run AI workflows defined in a YAML file.

## Commands

- Default (tests + lint): `bundle exec rake`
- Test all: `bundle exec test`
- Run single test: `bundle exec ruby -Itest test/path/to/test_file.rb`
- Lint: `bundle exec rubocop`
- Lint (with autocorrect, preferred): `bundle exec rubocop -A`
- Whenever you want to run the whole test suite just run `bundle exec rake` to also run linting, and note the linting errors too (most will auto correct but not all)
- **Run roast locally**: Use `bin/roast` (not `bundle exec roast` which may use the installed gem)
- Alternative: `bundle exec exe/roast`

## Tech stack
- `thor` and `cli-ui` for the CLI tool
- Testing: Use Minitest, VCR for HTTP mocking, test files named with `_test.rb` suffix
- Prefer using the more literate `test "this is a test description" do` type of testing that we get from extending ActiveSupport::TestCase over the primitive XUnit-style def test_description headings for tests

## Code Style Guidelines

- Naming: snake_case for variables/methods, CamelCase for classes/modules, ALL_CAPS for constants
- Module structure: Use nested modules under the `Roast` namespace
- Command pattern: Commands implement a `call` method and class-level `help` method
- Error handling: Use custom exception classes and structured error handling
- Errors that should stop the program execution should `raise(CLI::Kit::Abort, "Error message")`
- Documentation: Include method/class documentation with examples when appropriate
- Dependencies: Prefer existing gems in the Gemfile before adding new ones
- Define class methods inside `class << self; end` declarations.
- Add runtime dependencies to `roast.gemspec`.
- Add development dependencies to `Gemfile`.
- Don't ever test private methods directly. Specs should test behavior, not implementation.
- I do not like test-specific code embedded in production code, don't ever do that
- **Do not use require_relative**
- Require statements should always be in alphabetical order

## Git Workflow Practices

1. **Amending Commits**:
   - Use `git commit --amend --no-edit` to add staged changes to the last commit without changing the commit message
   - This is useful for incorporating small fixes or changes that belong with the previous commit
   - Be careful when amending commits that have already been pushed, as it will require a force push

2. **Force Pushing Safety**:
   - Always use `git push --force-with-lease` rather than `git push --force` when pushing amended commits
   - This prevents accidentally overwriting remote changes made by others that you haven't pulled yet
   - It's a safer alternative that respects collaborative work environments

4. **PR Management**:
   - Pay attention to linting results before pushing to avoid CI failures

## GitHub API Commands
To get comments from a Pull Request using the GitHub CLI:

```bash
# Get review comments from a PR
gh api repos/Shopify/roast/pulls/{pr_number}/comments

# Get issue-style comments
gh api repos/Shopify/roast/issues/{pr_number}/comments

# Filter comments from a specific user using jq
gh api repos/Shopify/roast/pulls/{pr_number}/comments | jq '.[] | select(.user.login == "username")'

# Get only the comment content
gh api repos/Shopify/roast/pulls/{pr_number}/comments | jq '.[].body'
```

### Creating and Managing Issues via API

```bash
# Create a new issue
gh api repos/Shopify/roast/issues -X POST -F title="Issue Title" -F body="Issue description"

# Update an existing issue
gh api repos/Shopify/roast/issues/{issue_number} -X PATCH -F body="Updated description"

# Add a comment to an issue
gh api repos/Shopify/roast/issues/{issue_number}/comments -X POST -F body="Comment text"
```

### Creating and Managing Pull Requests

```bash
# Create a new PR with a detailed description using heredoc
gh pr create --title "PR Title" --body "$(cat <<'EOF'
## Summary

Detailed description here...

## Testing

Testing instructions here...
EOF
)"

# Update an existing PR description
gh pr edit {pr_number} --body "$(cat <<'EOF'
Updated PR description...
EOF
)"

# Check PR details
gh pr view {pr_number}

# View PR diff
gh pr diff {pr_number}
```

#### Formatting Tips for GitHub API
1. Use literal newlines in the body text instead of `\n` escape sequences
2. When formatting is stripped (like backticks), use alternatives:
   - **Bold text** instead of `code formatting`
   - Add a follow-up comment with proper formatting
3. For complex issues, create the basic issue first, then enhance with formatted comments
4. Always verify the formatting in the created content
5. Use raw JSON for complex formatting requirements:
   ```bash
   gh api repos/Shopify/roast/issues -X POST --raw-field '{"title":"Issue Title","body":"Complex **formatting** with `code` and lists:\n\n1. Item one\n2. Item two"}'
   ```

## PR Review Best Practices
1. **Always provide your honest opinion about the PR** - be candid about both strengths and concerns
2. Give a clear assessment of risks, architectural implications, and potential future issues
3. Don't be afraid to point out potential problems even in otherwise good PRs
4. When reviewing feature flag removal PRs, carefully inspect control flow changes, not just code branch removals
5. Pay special attention to control flow modifiers like `next`, `return`, and `break` which affect iteration behavior
6. Look for variable scope issues, especially for variables that persist across loop iterations
7. Analyze how code behavior changes in all cases, not just how code structure changes
8. Be skeptical of seemingly simple changes that simply remove conditional branches
9. When CI checks fail, look for subtle logic inversions or control flow changes
10. Examine every file changed in a PR with local code for context, focusing on both what's removed and what remains
11. Verify variable initialization, modification, and usage patterns remain consistent after refactoring
12. **Never try to directly check out PR branches** - instead, compare PR changes against the existing local codebase
13. Understand the broader system architecture to identify potential impacts beyond the changed files
14. Look at both the "before" and "after" state of the code when evaluating changes, not just the diff itself
15. Consider how the changes will interact with other components that depend on the modified code
16. Run searches or examine related files even if they're not directly modified by the PR
17. Look for optimization opportunities, especially in frequently-called methods:
    - Unnecessary object creation in loops 
    - Redundant collection transformations
    - Inefficient filtering methods that create temporary collections
18. Prioritize code readability while encouraging performance optimizations:
    - Avoid premature optimization outside of hot paths
    - Consider the tradeoff between readability and performance
    - Suggest optimizations that improve both clarity and performance