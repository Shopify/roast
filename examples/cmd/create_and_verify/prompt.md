# Creating and Verifying Files

Now let's see how command functions can work together:

**Step 1: Create a test directory**
Using `mkdir(args: "-p test_cmd_demo")`:

**Step 2: Create a file with echo**
Using `echo(args: "This file was created by command functions! > test_cmd_demo/demo.txt")`:

**Step 3: Verify our work**
Using `ls(args: "-la test_cmd_demo/")`:

**Step 4: Display the file contents**
Using `cat(args: "test_cmd_demo/demo.txt")`:

**Step 5: Clean up**
Using `echo(args: "Demo complete! You can remove test_cmd_demo when ready.")`:

This demonstrates how command functions can be combined to perform useful tasks while maintaining security through the allowed commands list.
