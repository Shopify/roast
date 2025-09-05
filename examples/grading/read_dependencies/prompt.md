Use the provided functions to find and read important dependencies of the provided test file named <%= workflow.file %>.

The first dependency you should always look for is the source file for the prime subject of the test (whatever class this test file is claiming to test). Use `read_file` to read the subject's source code into your conversation transcript, but only if it's not already there from a previous chat.

If you can identify other important application-level dependencies then read them too.
How many extra dependencies to research is left to your discretion, but ALWAYS make sure you have the subject under test (SUT) in your context before responding.

Once you are finished using tool functions, respond with the relative path to the source file of the SUT inside <sut> tags. IMPORTANT: Include the full relative path from the project root, including any directory prefixes like lib/, app/, etc.

Example:

If you are told to find the dependencies of `test/services/country_db_interface_test.rb`,
then you would use the functions as explained above and ultimately respond with `<sut>app/services/country_db_interface.rb</sut>`

If the file is found at `lib/roast/workflow/workflow_initializer.rb`, respond with `<sut>lib/roast/workflow/workflow_initializer.rb</sut>` (include the lib/ prefix)
