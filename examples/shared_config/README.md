# Shared Configuration Example

This example demonstrates how to use `shared.yml` to define common configuration anchors that can be referenced across multiple workflow files.

## Structure

```
├── shared.yml                      # Common configuration anchors
└── example_with_shared_config/
    └── workflow.yml               # Workflow using shared anchors
```

## How it works

1. When loading a workflow file, Roast checks if `shared.yml` exists one level above the workflow directory
2. If found, it loads `shared.yml` first, then the workflow file
3. This allows YAML anchors defined in `shared.yml` to be referenced in workflow files

## Example Usage

In `shared.yml`:
```yaml
standard_tools: &standard_tools
  - Roast::Tools::Grep
  - Roast::Tools::ReadFile
  - Roast::Tools::WriteFile
  - Roast::Tools::SearchFile

mirage: &mirage '$(echo "Oh my god. Its a mirage")'
```

In your workflow:
```yaml
name: Example with shared config
tools: *standard_tools  # Reference the standard tools from shared.yml

steps:
  - *mirage  # Reference a shared step definition
  - sabotage: '$(echo "Im tellin yall, its sabotage")'
```

## Running the Example

```bash
# Run the workflow that uses shared configuration
roast execute examples/shared_config/example_with_shared_config/workflow.yml
```

The workflow will:
1. Load the shared configuration from `shared.yml`
2. Apply the referenced tools and steps
3. Execute the workflow with the merged configuration
