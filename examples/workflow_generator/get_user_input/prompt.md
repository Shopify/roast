You need to collect user input for generating a new workflow.

Step 1: Ask for the workflow description using ask_user tool with prompt: "What should your workflow do?"

Step 2: Ask for the workflow name using ask_user tool with prompt: "Enter workflow directory name:"

Step 3: Return the result in JSON format:

<json>
{
  "user_description": "what the user wants the workflow to do", 
  "workflow_name": "directory_name_provided_by_user"
}
</json>