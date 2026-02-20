Write documentation comments for public methods in the specified file or class.

## Arguments

Accepts either:
- A file path, like `lib/roast/cogs/chat/config.rb`
- A class name, like `Roast::Cogs::Chat::Config`

## Task

Following the guidelines in `internal/documentation/`:

1. **Determine documentation type:**
   - For Config, Input, Output classes → Use `doc-comments-external.md` (user-facing, thorough)
   - For cog classes, Params classes, `execute` methods, internal utilities → Use `doc-comments-internal.md` (developer-facing, concise)
   - See `doc-comments.md` for the distinction

2. Review existing documentation comments in the target file/class
3. Write doc comments for any public methods that lack them
4. Update existing doc comments to match current standards
5. Cross-reference related methods (for user-facing documentation only)
6. Replace any rough developer notes with polished documentation

**Note:** User-facing documentation should be thorough with `#### See Also` sections.
Developer-facing documentation should be concise without cross-references.

## Important Constraints

- Only examine and modify files in the `lib/roast/` directory
- Only write/edit comments in the specific file or class requested
- Ignore `field` definitions in Config classes
- Do not modify any other files

## Immediate Instructions

Operate on this file/class: $ARGUMENTS
