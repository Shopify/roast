Write documentation comments for public methods in the specified file or class.

## Arguments

Accepts either:
- A file path, like `lib/roast/dsl/cogs/chat/config.rb`
- A class name, like `Roast::DSL::Cogs::Chat::Config`

## Task

Following the guidelines in `internal/documentation/doc-comments.md`:

1. Review existing documentation comments in the target file/class
2. Write doc comments for any public methods that lack them
3. Update existing doc comments to match current standards
4. Cross-reference related methods, including newly documented ones
5. Replace any rough developer notes with polished documentation

Focus only on public interface methods in Params, Config, Input, and Output classes within `lib/roast/dsl/`.

## Important Constraints

- Only examine and modify files in the `lib/roast/dsl/` directory
- Only write/edit comments in the specific file or class requested
- Ignore `field` definitions in Config classes
- Do not modify any other files

## Immediate Instructions

Operate on this file/class: $ARGUMENTS
