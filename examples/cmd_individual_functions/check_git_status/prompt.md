# Understanding Your Git Repository

Now let's explore the version control status of your project using the `git()` command function.

**Repository Status:**
I'll use `git(args: "status")` to see the current state of your repository:

**Branch Information:**
Let's check which branch we're on and what other branches exist using `git(args: "branch -a")`:

**Recent History:**
To understand recent changes, I'll show the last 5 commits using `git(args: "log --oneline -5")`:

**Working with Git Commands:**
The `git()` function accepts any git subcommand and options through the `args` parameter. Some useful examples:
- `git(args: "diff")` - See uncommitted changes
- `git(args: "remote -v")` - View remote repositories
- `git(args: "log --graph --oneline -10")` - Visual branch history

This gives you powerful version control capabilities right within your Roast workflows!
