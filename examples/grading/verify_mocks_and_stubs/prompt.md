Find places in the provided test code where stubbing and mocking are used. Search for the corresponding implementation source code of those dependencies elsewhere in the codebase to validate that the stub or mock matches the implementation that it is doubling. Use the tool functions provided to find and read the dependencies.

Once you've found the dependencies, verify that any mocks and stubs accurately reflect the real implementation. If there are discrepancies, list them out alphabetically with:

1. The name of the mocked/stubbed method
2. What the mock/stub expects in terms of arguments and/or return values
3. What the actual implementation actually takes as arguments and returns
4. Suggestions for fixing the discrepancy

Note: If there are no discrepancies, do not summarize those that accurately reflect their real implementations in the codebase, just respond "All mocks and stubs verified."

IMPORTANT: There's absolutely no need for you to waste time grepping for methods/functions that you know belong to testing libraries such as Mocha's `expects` and `stubs`. Only search for the implementation of things that are stubbed and/or mocked in the test to verify whether the test code matches the implementation code.
