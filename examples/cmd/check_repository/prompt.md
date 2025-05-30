# Repository Status Check

You need to analyze the Git repository status and provide a comprehensive overview of the repository state, history, and configuration.

**SPECIFIC COMMANDS TO USE:**
1. Check repository status: `git status`
2. Show current branch: `git branch --show-current`
3. List recent commits: `git log --oneline -10`
4. Show remote repositories: `git remote -v`

**EFFICIENCY RULES:**
- Run each command ONLY ONCE - do not repeat any git command
- DO NOT try different variations of the same command (e.g., different log formats)
- Gather all needed information with these 4 commands only

From these commands, analyze:
- Current branch and its state
- Working directory status (clean/dirty)
- Recent commit activity
- Remote repository configuration
- Overall repository health

RESPONSE FORMAT
Provide your analysis in JSON format:

<json>
{
  "repository_status": {
    "current_branch": "main",
    "working_directory": {
      "is_clean": false,
      "modified_files": 3,
      "untracked_files": 2,
      "staged_changes": 1
    },
    "recent_activity": {
      "total_recent_commits": 10,
      "latest_commit": {
        "hash": "abc1234",
        "message": "Latest commit message"
      },
      "activity_summary": "Regular commits indicate active development"
    },
    "remotes": {
      "origin": {
        "fetch_url": "https://github.com/user/repo.git",
        "push_url": "https://github.com/user/repo.git"
      }
    },
    "repository_health": {
      "status": "healthy",
      "notes": "Repository has uncommitted changes but is otherwise in good state"
    }
  },
  "analysis_complete": true
}
</json>
