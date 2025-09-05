# Changesets

This directory contains "changeset" files that describe changes made in pull requests. These files are used to automate version bumps and changelog generation.

## Creating a Changeset

When you make changes that should be included in the next release, you need to create a changeset file:

### Method 1: Using rake task (recommended)
```bash
bundle exec rake changeset:add
```

This will prompt you for:
- The type of change (patch/minor/major)
- A brief description of your changes

### Method 2: Manual creation
Create a new markdown file in this directory with a descriptive name (e.g., `fix-workflow-bug.md`):

```markdown
---
type: patch
---

Fixed bug in workflow execution that caused steps to run out of order
```

## Changeset Format

Each changeset file must have:
1. **Frontmatter** with a `type` field
2. **Description** of the changes

### Version Bump Types

- **patch**: Bug fixes, minor improvements, documentation updates (0.0.X)
- **minor**: New features that are backwards compatible (0.X.0)
- **major**: Breaking changes that are not backwards compatible (X.0.0)

## Examples

### Patch Release
```markdown
---
type: patch
---

Fixed error handling in workflow executor
```

### Minor Release
```markdown
---
type: minor
---

Added support for parallel step execution
```

### Major Release
```markdown
---
type: major
---

Renamed workflow configuration keys for better clarity (breaking change)
```

## Skipping Changesets

Some PRs don't require a version bump (e.g., CI changes, documentation updates, tests). To skip the changeset requirement, add the `🤖 Skip Changelog` label to your PR.

## How It Works

1. **During PR**: The CI checks that a changeset file exists
2. **After merge to main**: An automated PR is created/updated with all pending changesets
3. **Release PR merge**: Version is bumped, changelog updated, and gem published to RubyGems

## Multiple Changes in One PR

If your PR includes multiple distinct changes, you can create multiple changeset files:
- `add-retry-mechanism.md` (minor)
- `fix-timeout-bug.md` (patch)

The highest severity change determines the version bump (in this case: minor).