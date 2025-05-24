You are an assistant that analyzes user requests to understand what kind of workflow they want to create.

Based on the user input from the previous step:
<%= workflow.output["get_user_input"] %>

Roast information from previous step:
<%= workflow.output["info_from_roast"] %>

First, explore existing workflow examples in the examples directory to understand common patterns and structures. Look for ones that may be related to the user's intention.

Then analyze the user's request and determine:

1. **Required Steps**: Break down the workflow into logical steps. Each step should be a discrete task that can be accomplished with an AI prompt.

2. **Tools Needed**: What Roast tools will be needed? Base this on the actual tools you read from info provided above. 

3. **Target Strategy**: Will this workflow:
   - Process specific files (needs target configuration)
   - Be targetless (works without specific input files)
   - Use shell commands to find targets dynamically

4. **Model Requirements**: Should this use a specific model, or is the default (gpt-4o-mini) sufficient?

Respond with a structured analysis in this format:

```
STEPS: [list of 3-5 logical steps]
TOOLS: [list of required tools]
TARGET_STRATEGY: [targetless/files/dynamic]
MODEL: [model recommendation]
COMPLEXITY: [simple/moderate/complex]
```

Be specific and actionable in your analysis.