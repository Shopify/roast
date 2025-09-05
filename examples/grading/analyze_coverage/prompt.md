<coverage_results>
<%= workflow.output["run_coverage"] %>
</coverage_results>

Analyze the results and score them on a scale of 1-10 using the following rubrics:

<line_coverage>
0-1: Critical failure (0-20% coverage) - Core functionality remains completely untested
2-3: Poor coverage (21-40%) - Major gaps; many key functions lack any testing
4-5: Inadequate coverage (41-60%) - Several important code paths are not executed
6-7: Moderate coverage (61-80%) - Notable gaps remain; some important functionality lacks coverage
8-9: Good coverage (81-95%) - Only minor or edge case code paths remain untested
10: Excellent coverage (96-100%)
</line_coverage>

<branch_coverage>
0-1: Critical failure (0-20% branch coverage) - Almost no conditional branches are tested
2-3: Poor coverage (21-40%) - Most conditional logic remains untested
4-5: Inadequate coverage (41-60%) - Many conditions are only tested for one outcome
6-7: Moderate coverage (61-80%) - Some conditions lack testing for all outcomes
8-9: Good coverage (81-95%) - Most conditions are tested for most outcomes
10: Excellent coverage (96-100%)
</branch_coverage>

<method_coverage>
0-1: Critical failure (0-20% method coverage) - Most or core functionality methods are untested
2-3: Poor coverage (21-40%) - Several public API methods remain untested
4-5: Inadequate coverage (41-60%) - Some important public methods lack tests
6-7: Moderate coverage (61-80%) - Notable gaps remain; some public methods may lack comprehensive testing
8-9: Good coverage (81-95%) - Nearly all public methods are tested; private methods are mostly covered via public method tests
10: Excellent coverage (96-100%)
</method_coverage>

RESPONSE FORMAT
You must respond in JSON format within <json> XML tags. Example:

<json>
{
  "method_coverage": {
    "score": "10",
    "justification": "The source file has 100% method coverage, indicating all methods are being tested."
  },
  "line_coverage": {
    "score": 10,
    "justification": "The source file has 100% line coverage, indicating all executable lines are tested."
  },
  "branch_coverage": {
    "score": 8,
    "justification": "The source file has 80% branch coverage, indicating some branches need testing."
  }
}
</json>
