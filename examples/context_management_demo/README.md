# Context Management Demo

This example demonstrates Roast's automatic context management feature, which helps prevent workflow failures when conversation history exceeds the LLM's context window.

## Features Demonstrated

1. **Automatic Token Tracking**: Monitors token usage throughout workflow execution
2. **Configurable Thresholds**: Set when to trigger warnings or compaction
3. **Context Preservation**: Specify critical steps to retain during compaction

## Configuration

```yaml
context_management:
  enabled: true          # Enable context management
  strategy: auto         # Compaction strategy (auto, summarize, prune, none)
  threshold: 0.8         # Trigger at 80% of context window
  max_tokens: 10000      # Override default limit (for demo purposes)
  retain_steps:          # Steps to always keep in full
    - analyze_requirements
    - generate_summary
```

## Running the Demo

```bash
roast execute context_management_demo
```

The workflow intentionally generates verbose responses to demonstrate how context management handles large amounts of text without failing.

## What to Observe

1. **Token Usage Warnings**: Watch for warnings as the context approaches limits
2. **Automatic Handling**: The workflow continues even with large outputs
3. **Preserved Context**: Critical steps remain accessible throughout execution

## Customization

Try modifying the configuration:
- Lower `max_tokens` to trigger compaction sooner
- Change `strategy` to test different compaction approaches
- Add more steps to `retain_steps` to preserve additional context