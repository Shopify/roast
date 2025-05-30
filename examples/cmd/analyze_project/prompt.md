# Project Analysis

You need to analyze the current project to identify its type, available tools, and development setup. Gather comprehensive information to understand the project's nature and configuration.

Investigate the project to determine:

1. Your current working location
2. The project structure and contents
3. Whether this is a Node.js project (look for package.json)
4. Whether Docker is configured (look for Dockerfile or docker-compose.yml)
5. Whether there's a Makefile for build automation
6. The version control state

Based on your findings, determine:
- Project type (Node.js application, containerized service, make-based project, etc.)
- Available development tools and configurations
- How dependencies are managed
- Version control status
- Recommended next steps for development

RESPONSE FORMAT
Provide your analysis in JSON format:

<json>
{
  "project_analysis": {
    "working_directory": "/path/to/project",
    "project_type": "Identified based on available files",
    "detected_tools": {
      "node_project": {
        "has_package_json": false,
        "has_lock_file": false,
        "package_manager": "none"
      },
      "containerization": {
        "has_dockerfile": false,
        "has_compose": false,
        "docker_ready": false
      },
      "build_system": {
        "has_makefile": false,
        "make_targets": []
      },
      "version_control": {
        "has_git": true,
        "working_tree_clean": false,
        "uncommitted_changes": 3
      }
    },
    "recommendations": [
      "Relevant recommendations based on what was found"
    ],
    "confidence": "high"
  },
  "analysis_complete": true
}
</json>
