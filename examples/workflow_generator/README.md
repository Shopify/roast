# Workflow Generator

This workflow generates new Roast workflows based on user descriptions. It's the engine behind the "New from prompt" option in `roast init`.

## How It Works

The workflow generator takes a user description and workflow name, then:

1. **Analyzes the request** - Understands what type of workflow is needed, what steps are required, and what tools should be used
2. **Generates structure** - Creates a complete workflow configuration including YAML and step prompts
3. **Creates files** - Writes all the necessary files and directories to disk

## Usage

This workflow is typically invoked automatically by the `roast init` command, but can also be run directly:

```bash
# Run the generator workflow
roast execute examples/workflow_generator/workflow.yml
```

## Generated Output

The workflow creates a new directory with:
- `workflow.yml` - Main workflow configuration
- `step_name/prompt.md` - Individual step prompts
- `README.md` - Documentation for the generated workflow
