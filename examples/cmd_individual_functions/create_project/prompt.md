# Building Your Project Structure

Let me show you how to create a well-organized project using command functions!

**Step 1: Check Our Starting Point**
First, I'll use `pwd()` to confirm where we're creating the project:

**Step 2: Create the Directory Structure**
I'll create a sample Ruby project structure. Watch how I use `mkdir` with the `-p` flag to create nested directories:

- Using `mkdir(args: "-p sample_project/lib/sample_project")` for the main code
- Using `mkdir(args: "-p sample_project/test")` for tests
- Using `mkdir(args: "-p sample_project/docs")` for documentation

**Step 3: Add Essential Files**
Now I'll create some important files using the `write_file` tool:

1. Create `sample_project/README.md`:
```markdown
# Sample Project

This project was created using Roast command functions!

## Structure
- `lib/` - Main application code
- `test/` - Test files
- `docs/` - Documentation
```

2. Create `sample_project/.gitignore`:
```
*.gem
.bundle/
Gemfile.lock
```

**Step 4: Confirm Success**
Using `echo(args: "✅ Project structure created successfully!")` to celebrate:

This demonstrates how command functions and file operations work together to automate project setup!
