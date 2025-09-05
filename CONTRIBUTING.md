# How to contribute

## Things we will merge

* Bugfixes
* Performance improvements
* Features that are likely to be useful to the majority of Roast users
* Documentation updates that are concise and likely to be useful to the majority of Roast users

## Things we won't merge

* Code that introduces considerable performance degrations
* Code that touches performance-critical parts of Roast and comes without benchmarks
* Features that are not important for most people (we want to keep the core Roast code small and tidy)
* Features that can easily be implemented on top of Roast
* Code that does not include tests
* Code that breaks existing tests
* Documentation changes that are verbose, incorrect or not important to most people (we want to keep it simple and easy to understand)

## Workflow

* [Sign the CLA](https://cla.shopify.com/) if you haven't already
* Fork the Roast repository
* Create a new branch in your fork
  * For updating [Roast documentation](https://shopify.github.io/roast/), create it from `gh-pages` branch. (You can skip tests.)
* If it makes sense, add tests for your code and/or run a performance benchmark
* Make sure all tests pass (`bundle exec rake`)
* **Create a changeset for your changes** (see [Changeset Requirements](#changeset-requirements) below)
* Create a pull request

## Changeset Requirements

All pull requests that modify the gem's functionality require a changeset file. This helps us automate version bumping and changelog generation.

### Creating a Changeset

Run the following command and follow the prompts:

```bash
bundle exec rake changeset:add
```

This will ask you to:
1. Select the type of change (patch/minor/major)
2. Provide a brief description of your changes

### Version Bump Guidelines

* **patch**: Bug fixes, minor improvements, documentation updates
* **minor**: New features that are backwards compatible
* **major**: Breaking changes that are not backwards compatible

### Skipping Changesets

Some changes don't require version bumps:
* CI/CD configuration changes
* Development tooling updates
* Test-only changes
* Documentation typo fixes

To skip the changeset requirement, add the `🤖 Skip Changelog` label to your PR.

### Multiple Changes

If your PR includes multiple distinct changes, you can create multiple changeset files by running `bundle exec rake changeset:add` multiple times.

## Releasing

Releases are now automated! When PRs with changesets are merged to `main`:

1. A "Release PR" is automatically created/updated that:
   * Collects all pending changesets
   * Determines the appropriate version bump
   * Updates `lib/roast/version.rb`
   * Updates `CHANGELOG.md`

2. When the Release PR is merged:
   * The gem is automatically built and published to RubyGems
   * A GitHub release is created with the changelog

No manual version bumping or changelog editing required!
