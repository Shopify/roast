# Intelligent Tool Selection Examples

You are demonstrating intelligent tool selection by completing various development tasks. Select and use the most appropriate tools based on what each task requires.

**CRITICAL GUIDELINES:**
- When working with JSON data, you MUST use jq to parse it - never return raw JSON
- Be efficient - if a command fails, do NOT repeat it
- Combine tools with pipes when needed (e.g., `curl -s ... | jq ...`)
- Check for files ONLY ONCE - if they don't exist, note it and move on

Complete the following development tasks:

## Task 1: API Health Check
Check if the GitHub API is accessible and responding properly.
- Target: https://api.github.com
- Goal: Verify the API returns a successful response (check HTTP status)

## Task 2: Parse JSON Response
Fetch GitHub's public information and extract specific data fields.
- Target: https://api.github.com/users/github
- Extract: The name and company fields from the JSON response
- **REQUIRED**: Use curl to fetch and jq to parse in a single command: `curl -s <url> | jq '<filter>'`

## Task 3: Check Container Environment
Determine if Docker is available and check for running containers.
- Try `docker ps` ONCE
- If Docker daemon is not running, note this and move on - do NOT retry

## Task 4: Check for Node.js Project
Investigate if this is a Node.js project and examine its dependencies.
- Check for package.json ONCE with `ls package.json`
- If not found, note this and move on - do NOT retry

## Task 5: Check Build System
Determine if a build system is configured and what targets are available.
- Check for Makefile ONCE with `ls Makefile`
- If not found, note this and move on - do NOT retry

**EFFICIENCY REMINDER**: Each file check or failed command should be attempted ONLY ONCE.

RESPONSE FORMAT
Report your findings in JSON format:

<json>
{
  "tool_selection_demo": {
    "task_1_api_check": {
      "tool_selected": "curl",
      "command_used": "curl -I https://api.github.com",
      "rationale": "Selected HTTP request tool for API check",
      "result": {
        "api_accessible": true,
        "status_code": 200
      }
    },
    "task_2_json_parsing": {
      "tools_selected": ["curl", "jq"],
      "command_used": "curl -s https://api.github.com/users/github | jq '.name, .company'",
      "rationale": "Combined tools for fetching and parsing JSON",
      "result": {
        "data_extracted": true,
        "fields": {
          "name": "GitHub",
          "company": "@github"
        }
      }
    },
    "task_3_containers": {
      "tool_selected": "docker",
      "command_used": "docker ps",
      "rationale": "Selected container platform tool",
      "result": {
        "docker_available": false,
        "error": "Docker daemon not running",
        "containers_running": 0
      }
    },
    "task_4_nodejs": {
      "tool_selected": "ls",
      "command_used": "ls package.json",
      "rationale": "Checked for package.json existence",
      "result": {
        "is_node_project": false,
        "package_json_found": false
      }
    },
    "task_5_build": {
      "tool_selected": "ls",
      "command_used": "ls Makefile",
      "rationale": "Checked for Makefile existence",
      "result": {
        "makefile_found": false,
        "targets": []
      }
    }
  },
  "summary": "Successfully demonstrated intelligent tool selection based on task requirements"
}
</json>
