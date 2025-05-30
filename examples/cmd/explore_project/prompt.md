# Exploring Your Project Structure

You need to analyze the project structure and provide a comprehensive overview. Gather information about the project layout, documentation, and configuration.

**IMPORTANT COMMAND SYNTAX:**
- The `find` command requires a path: `find . -name "*.md"` (not `find -name "*.md"`)
- Use `head` to limit output: `find . -name "*.md" | head -10`
- Check files efficiently - don't repeat commands

Explore the project by:

1. Identifying your current location: use `pwd`
2. Listing all files and directories: use `ls -la`
3. Finding documentation files: use `find . -name "*.md" -type f | head -10`
4. Examining the README: use `cat README.md | head -20` (if it exists)
5. Locating configuration files: use `find . -name "*.yml" -o -name "*.yaml" | grep -E "(config|workflow)" | head -10`

**EFFICIENCY RULES:**
- Run each command ONLY ONCE
- If a file doesn't exist, note it and move on
- DO NOT retry failed commands

Based on your exploration, analyze:
- Project root location and overall structure
- Key directories and their likely purposes
- Available documentation
- Configuration files present
- General project organization

RESPONSE FORMAT
Provide your analysis in JSON format:

<json>
{
  "project_analysis": {
    "current_directory": "/path/to/project",
    "total_items": {
      "files": 0,
      "directories": 0,
      "hidden_items": 0
    },
    "documentation": {
      "readme_found": true,
      "readme_summary": "Brief summary of README contents",
      "other_docs": ["list of other .md files found"]
    },
    "configuration": {
      "config_files": ["list of .yml/.yaml configuration files"],
      "workflow_files": ["list of workflow-related files"]
    },
    "project_structure": {
      "key_directories": [
        {
          "name": "src",
          "purpose": "Source code directory"
        },
        {
          "name": "test",
          "purpose": "Test files directory"
        }
      ],
      "project_type": "Identified project type based on files present"
    }
  },
  "exploration_complete": true
}
</json>
