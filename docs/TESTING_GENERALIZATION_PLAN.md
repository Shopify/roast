# Generalize VCR Testing Infrastructure for User Workflows

**Status**: Implemented in #835

**Related Issues**:
- #570 - Migrate YAML workflow Examples to DSL (VCR infrastructure completed)
- #682 - Improve unit test coverage for lib/roast/ classes
- #835 - Generalize testing infrastructure for user workflows

**Context**: The VCR testing infrastructure was successfully implemented for the examples tests in PR #655. This plan was executed to generalize that system so any Roast user can write tests for their own workflows.

## Implementation Summary

### Decisions Made

1. **Naming**: `Roast::Testing::WorkflowTest` — follows Rails convention (`ActiveJob::TestHelper`, etc.)
2. **VCR**: Optional dependency — `defined?(VCR)` guard with graceful fallback to live execution
3. **Generator**: Deferred — not needed for initial release, docs and examples are sufficient
4. **Test Location**: User's choice — no prescribed location, just `require "roast/testing/workflow_test"`
5. **Autoloading**: `lib/roast/testing/` is ignored by Zeitwerk — explicit `require` is intentional API design

### Completed Steps

- [x] **Extract Test Helper to Public API** — `lib/roast/testing/workflow_test.rb`
  - `Roast::Testing::WorkflowTest` with configurable `workflow_dir`, `cassette_library_dir`, `sandbox_root`, `fixture_dir`
  - `in_sandbox` for isolated workflow execution
  - `use_command_runner_fixture` for agent transcript testing
  - `EMPTY_PARAMS` convenience constant
- [x] **VCR as Optional Dependency** — `defined?(VCR)` guards, auto-configuration with skip-if-already-configured
- [x] **Testing Documentation** — `docs/TESTING.md` with quick start, VCR, agents, configuration, troubleshooting
- [x] **Annotated Example Test** — `examples/test/example_workflow_test.rb` with 4 passing example tests
- [x] **Internal backward compatibility** — `Examples::FunctionalTest` is now a thin wrapper, all 874 existing tests pass

### Deferred

- [ ] **Generator** (`roast test:init`) — nice-to-have, can be added later
- [ ] **README Testing section** — add link to `docs/TESTING.md` from main README

## Key Files

| File | Purpose |
|------|---------|
| `lib/roast/testing/workflow_test.rb` | Public API — the base test class |
| `docs/TESTING.md` | User-facing documentation |
| `examples/test/example_workflow_test.rb` | Annotated example tests |
| `examples/test/test_helper.rb` | Example test helper |
| `test/examples/support/functional_test.rb` | Internal thin wrapper (backward compat) |
