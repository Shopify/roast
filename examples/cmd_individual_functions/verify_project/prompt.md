# Verifying Your Project

Now let's verify that our project was created correctly. This teaches you how to inspect and validate file structures.

**Step 1: List the Project Directory**
I'll use `ls(args: "-la sample_project/")` to see all files and directories we created:

**Step 2: Check the Directory Tree**
Let's examine the subdirectories using `ls(args: "-R sample_project/")` for a recursive listing:

**Step 3: Verify File Contents**
I'll use `cat()` to display the contents of our created files:

- Using `cat(args: "sample_project/README.md")` to show the README:
- Using `cat(args: "sample_project/.gitignore")` to show the gitignore:

**Step 4: Summary**
Finally, I'll use `echo(args: "🎯 Project verification complete! All files and directories are in place.")`:

**What You've Learned:**
- How to create complex directory structures with `mkdir`
- How to combine command functions with file operations
- How to verify your work using `ls` and `cat`
- How command functions make automation tasks clearer and safer

You can now apply these patterns to automate your own project setups!
