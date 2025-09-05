These are the key testing guidelines to consider in your evaluation:

- Tests should serve as specifications that define expected behaviors
- Tests should have descriptive names that clearly communicate intent
- Tests should focus on behavior rather than implementation details
- Excessive mocking/stubbing should be avoided in favor of testing real behavior
- Tests should be well-structured with minimal setup complexity
- Tests should be maintainable and not break when implementation details change
- Tests should cover edge cases and error conditions
- Tests should follow proper naming conventions and directory structure
- Tests should not modify the behaviour of the code being tested (e.g. making a private method public in tests)

Now consider the full transcript and evaluate the test being graded based on the following rubrics on a scale of 1-10:

<test_helpers>
0-1: Extremely poor helper usage - Helpers used incorrectly or inappropriately, making tests harder to understand
2-3: Poor helper usage - Helpers are poorly designed, tightly coupled to implementation, or used incorrectly
4-5: Basic helper usage - Helpers work but may be poorly organized or not reusable
6-7: Good helper usage - Helpers are well-designed and used appropriately
8-9: Very good helper usage - Helpers are well-factored, reusable, and make tests clearer
10: Excellent helper usage - Helpers are perfectly designed, highly reusable, and significantly improve test clarity and maintainability. Also give this score to tests that DO NOT use test helpers at all.
</test_helpers>

<mocks_and_stubs>
0-1: Extremely poor mocking - Mocks/stubs used incorrectly or excessively, completely hiding real behavior
2-3: Poor mocking - Heavy reliance on mocks that couple tests to implementation; mocks don't match real behavior
4-5: Basic mocking - Mocks used appropriately but may be overused or not match implementation exactly
6-7: Good mocking - Mocks used judiciously where needed; generally match implementation
8-9: Very good mocking - Minimal mocking focused on external dependencies; accurately reflects real behavior
10: Excellent mocking - Mocks used only where absolutely necessary (external APIs, etc); perfectly match real implementations; maintain loose coupling
</mocks_and_stubs>

<readability>
0-1: Extremely poor readability - Test purpose is impossible to understand; no structure or organization
2-3: Poor readability - Test names are vague or misleading; structure is confusing with no clear assertions
4-5: Basic readability - Structure is understandable but not optimized for clarity
6-7: Good readability - Structure is logical with clear assertions
8-9: Very readable - Well-organized with explicit, meaningful test names and assertions
10: Exceptionally readable - Test names serve as perfect specifications; elegant structure with context-providing descriptions; self-documenting with clear setup, execution, and verification phases
</readability>

<maintenability>
0-1: Extremely brittle - Tests are completely coupled to implementation details
2-3: Highly unmaintainable - Will require significant rework when code changes because of heavy coupling to implementation details
4-5: Somewhat maintainable - Some coupling to implementation details
6-7: Reasonably maintainable - Tests mostly focus on behavior over implementation; limited coupling to implementation details
8-9: Highly maintainable - Tests focus on behavior rather than implementation; changes to implementation should rarely break tests
10: Exceptionally maintainable - Tests purely focus on behavior and public interfaces; implementation can be completely refactored without breaking tests; well-factored test helpers and fixtures
</maintenability>

<effectiveness>
0-1: Ineffective - Don't validate actual behavior and could pass even if code is broken
2-3: Minimally effective - Only the most basic functionality validated. Many incorrect behaviors would not be caught
4-5: Partially effective - Only catch obvious issues but miss subtle bugs; limited validation of actual outcomes
6-7: Reasonably effective - Should catch most common bugs
8-9: Highly effective - Should catch nearly all bugs
10: Exceptionally effective - Should catch even subtle edge case bugs; validate both positive and negative cases
</effectiveness>

While grading, consider the following goals as being applicable across all rubrics:

SUBJECTIVE:
- Well-written: Organized, easy to understand, and follow best practices
- Real behavior: Validate what the code does rather than implementation details
- Isolated: Should not depend on external systems, services, or APIs. Note: The use of fixtures such as `shops(:snowdevil)` is expected and should not be penalized. The only exception is when the SUT is being loaded as a fixture unnecessarily when it could be instantiated directly.

OBJECTIVE
- Idempotent: Should be able to run repeatedly without affecting outcome or side effects.
- Deterministic: Should produce the same results across all runs and environments.
- No sleep: Does not include sleep calls or rely on timing for synchronization.
- Concurrent: Properly handles concurrent execution paths without errors.
- Timeless: Does not depend on the current date or time. Will not fail due to changes such as daylight savings or leap years. Specifically with regards to handling time, look for anti-patterns like `Time.current + 7.days.to_i`, which fails on DST changes. The correct approach is `7.days.from_now`.

VIOLATING ANY OBJECTIVE GOAL SHOULD RESULT IN AN OVERALL SCORE LESS THAN 5!

Provide a brief justification for each score, using a maximum of 1-3 sentences. (Note that specific recommendations for improvement are not needed at this step.)

You are acting as a stern and relentless striver for excellence in programming, so you must be highly critical. The point of this grading exercise is to facilitate substantial improvement, not just stroking the programmer's ego. Do not hesitate to give a failing overall score (0) for serious violations!

RESPONSE FORMAT: You must respond in JSON format within <json> XML tags.

<json>
{
  "test_helpers": {
    "score": 4,
    "justification": "Helpers are used incorrectly in several places, reducing test maintainability and clarity. The assert_valid_record helper is being misused with hashes instead of model instances."
  },
  "mocks_and_stubs": {
    "score": 4,
    "justification": "Several mocks don't match the actual implementation, making tests brittle and potentially hiding production bugs. For example, mocking success: true when the service returns status: 'success'."
  },
  "readability": {
    "score": 8,
    "justification": "Test names clearly describe behavior being tested."
  },
  "maintainability": {
    "score": 6,
    "justification": "Tests mostly focus on behavior but have some coupling to implementation."
  },
  "effectiveness": {
    "score": 7,
    "justification": "Tests validate most expected behaviors and would catch common bugs."
  }
}
</json>
