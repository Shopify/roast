# Automatic Context Management Guide

This guide explains how to use and test the automatic context management feature in Roast, which prevents LLM context window overflows in long-running workflows.

## Overview

The context management feature automatically monitors token usage during workflow execution and compacts the conversation transcript when approaching model limits. This ensures workflows can continue indefinitely without hitting context window restrictions.

## Quick Start

### Basic Configuration

Add context management to any workflow:

```yaml
name: My Long Workflow
model: gpt-4o-mini
context_management:
  enabled: true
  threshold: 0.8  # Trigger at 80% of model's token limit
  strategy: truncation  # Fast, reliable strategy
```

### Setup for Testing with OpenRouter

For comprehensive testing with models like Google Gemini, set up OpenRouter:

1. **Get OpenRouter API Key**: Sign up at https://openrouter.ai/ and get your API key
2. **Set Environment Variable**: 
   ```bash
   export OPENROUTER_API_KEY="your-openrouter-api-key-here"
   ```
3. **Configure Workflow**:
   ```yaml
   name: Context Management Test
   api_provider: openrouter
   api_token: $(echo $OPENROUTER_API_KEY)
   model: google/gemini-2.0-flash-001
   context_management:
     enabled: true
     threshold: 0.6  # Trigger at 60% to test sooner
     strategy: llm_summarization
     max_tokens: 1000000
   ```

### Testing the Feature

Create a comprehensive test workflow to see context management in action:

```yaml
# context-test-workflow.yml
name: Context Management Test
api_provider: openrouter
api_token: $(echo $OPENROUTER_API_KEY)
model: google/gemini-2.0-flash-001

context_management:
  enabled: true
  threshold: 0.6  # Trigger at 60% to test sooner
  strategy: llm_summarization
  max_tokens: 1000000

tools:
  - Roast::Tools::ReadFile
  - Roast::Tools::WriteFile

steps:
  - detailed_analysis
  - code_review
  - security_audit
  - performance_review
  - documentation_review
  - final_report

# Step configurations to enable output saving
detailed_analysis:
  print_response: true
code_review:
  print_response: true
security_audit:
  print_response: true
performance_review:
  print_response: true
documentation_review:
  print_response: true
final_report:
  print_response: true
```

Create step directories with prompts (example for `detailed_analysis/prompt.md`):

```markdown
# Extremely Detailed Code Analysis

Please provide an exhaustive analysis of this code. Be very verbose and detailed:

<% if workflow.file %>
**File:** `<%= workflow.file %>`

```
<%= workflow.resource.contents %>
```

Provide detailed analysis covering:
1. **Line-by-line breakdown** - Go through each method
2. **Design patterns used** - Identify all patterns
3. **Data structures** - Analyze each variable and its purpose
4. **Method signatures** - Detailed parameter analysis
5. **Return values** - What each method returns and why
6. **Edge cases** - What could go wrong
7. **Memory usage** - How memory is managed
8. **Time complexity** - Big O analysis for each method
9. **Space complexity** - Memory requirements
10. **Ruby idioms** - What Ruby-specific features are used

Be extremely thorough and verbose in your analysis.
<% end %>
```

**Important**: Run from your workflow directory using relative paths:
```bash
cd your-test-directory
bundle exec /path/to/roast/exe/roast execute context-test-workflow.yml sample_code.rb -v
```

## Practical Example Workflows

### 1. Large Codebase Analysis

Perfect for testing context management with real data:

```yaml
# analyze-large-codebase.yml
name: Comprehensive Codebase Analysis
model: gpt-4o
context_management:
  enabled: true
  threshold: 0.75
  strategy: llm_summarization  # Preserves more context
  summarization_model: gpt-4o-mini  # Fast, cheap for summaries

tools:
  - Roast::Tools::ReadFile
  - Roast::Tools::Grep
  - Roast::Tools::WriteFile

steps:
  - analyze_structure: "Analyze the overall structure of this Ruby gem codebase"
  - read_core_files: "Read and analyze all files in lib/roast/ providing detailed insights"
  - check_patterns: "Search for common patterns like 'class', 'module', 'def' and analyze code organization"
  - review_tests: "Read test files and evaluate test coverage and quality"
  - identify_issues: "Identify potential code quality issues, anti-patterns, or improvements"
  - generate_recommendations: "Create detailed recommendations for code improvements"
  - write_report: "Write a comprehensive analysis report to analysis-report.md"
```

### 2. Documentation Generation Workflow

Tests context management with iterative content creation:

```yaml
# generate-comprehensive-docs.yml
name: Generate Comprehensive Documentation
model: claude-3-5-sonnet-20241022
context_management:
  enabled: true
  threshold: 0.8
  strategy: llm_summarization
  post_compaction_threshold_buffer: 0.85  # Keep more context

tools:
  - Roast::Tools::ReadFile
  - Roast::Tools::Grep
  - Roast::Tools::WriteFile

steps:
  - read_readme: "Read and understand the current README.md"
  - analyze_architecture: "Read lib/roast.rb and understand the gem's architecture"
  - study_workflow_system: "Read workflow-related files and understand the execution system"
  - examine_tools: "Read all tool files and understand available functionality"
  - review_examples: "Read example workflows and understand use cases"
  - create_api_docs: "Generate detailed API documentation for all public classes and methods"
  - write_user_guide: "Create a comprehensive user guide with examples"
  - generate_tutorials: "Create step-by-step tutorials for common use cases"
  - write_troubleshooting: "Create troubleshooting guide for common issues"
  - final_docs_review: "Review all generated documentation for consistency and completeness"
```

### 3. Multi-File Code Refactoring

Tests context management with code analysis and modifications:

```yaml
# refactor-codebase.yml  
name: Intelligent Code Refactoring
model: gpt-4o
context_management:
  enabled: true
  threshold: 0.7
  strategy: llm_summarization
  character_to_token_ratio: 0.25  # Conservative estimate

tools:
  - Roast::Tools::ReadFile
  - Roast::Tools::Grep
  - Roast::Tools::WriteFile

steps:
  - scan_codebase: "Scan the entire codebase to understand structure and identify refactoring opportunities"
  - find_duplicates: "Search for duplicate code patterns across files"
  - analyze_complexity: "Identify overly complex methods and classes that need simplification"
  - check_naming: "Review naming conventions and identify inconsistencies"
  - examine_dependencies: "Analyze class dependencies and coupling issues"
  - propose_refactoring: "Create detailed refactoring plan with specific recommendations"
  - implement_fixes: "Implement the most critical refactoring improvements"
  - validate_changes: "Review changes to ensure they maintain functionality"
  - update_tests: "Update or create tests for refactored code"
  - document_changes: "Document all changes made and their rationale"
```

### 4. API Integration Testing

Tests context management with external data processing:

```yaml
# api-data-processor.yml
name: API Data Processing Pipeline  
model: gpt-4o-mini
context_management:
  enabled: true
  threshold: 0.75
  strategy: truncation  # Fast processing for data workflows
  max_tokens: 100000  # Override if needed

tools:
  - Roast::Tools::ReadFile
  - Roast::Tools::WriteFile

steps:
  - setup_processing: "Set up data processing pipeline for API responses"
  - read_sample_data: "Read sample JSON data files from examples/ directory"
  - analyze_structure: "Analyze data structure and identify patterns"
  - design_schema: "Design optimal data schema for processing"
  - create_processors: "Create data processing functions"
  - validate_processing: "Validate data processing with sample data"
  - handle_errors: "Implement error handling for edge cases"
  - optimize_performance: "Optimize processing for large datasets"
  - generate_reports: "Create summary reports of processed data"
  - document_pipeline: "Document the complete processing pipeline"
```

## Testing Strategies

### 1. Threshold Testing

Test different threshold values to understand behavior:

```yaml
# Test with very low threshold (triggers immediately)
context_management:
  enabled: true
  threshold: 0.1

# Test with high threshold (rarely triggers)  
context_management:
  enabled: true
  threshold: 0.95
```

### 2. Strategy Comparison

Compare truncation vs LLM summarization:

```yaml
# Fast truncation strategy
context_management:
  enabled: true
  strategy: truncation
  
# Intelligent summarization strategy  
context_management:
  enabled: true
  strategy: llm_summarization
  summarization_model: gemini-2.0-flash  # Fast, cheap model
```

### 3. Buffer Testing

Test different buffer settings:

```yaml
# Aggressive compaction (more buffer space)
context_management:
  enabled: true
  post_compaction_threshold_buffer: 0.7

# Conservative compaction (preserves more context)
context_management:
  enabled: true
  post_compaction_threshold_buffer: 0.95
```

## Monitoring and Debugging

### Enable Debug Logging

Set `DEBUG=1` to see context management in action:

```bash
DEBUG=1 bin/roast your-workflow.yml
```

### Key Metrics to Watch

- **Token usage before/after compaction**: Shows compression effectiveness
- **Compaction frequency**: Indicates if threshold needs adjustment  
- **Strategy performance**: Compare speed and quality between strategies
- **Model selection**: Verify appropriate summarization models are chosen

### Common Issues and Solutions

**Issue**: Frequent re-compaction
**Solution**: Increase `post_compaction_threshold_buffer` or lower `threshold`

**Issue**: Too much context lost
**Solution**: Use `llm_summarization` strategy or increase buffer value

**Issue**: Slow performance
**Solution**: Use `truncation` strategy or faster `summarization_model`

**Issue**: Unexpected token counting
**Solution**: Adjust `character_to_token_ratio` for your specific models

### Important: Template Syntax

⚠️ **Critical Fix**: Use `workflow.resource.contents` (plural) in your ERB templates, not `workflow.resource.content` (singular):

```erb
<!-- ✅ Correct -->
<%= workflow.resource.contents %>

<!-- ❌ Incorrect - will cause "undefined method" errors -->
<%= workflow.resource.content %>
```

### Workflow Execution Best Practices

**Path Resolution**: For best results, run workflows from the directory containing your workflow files:

```bash
# ✅ Recommended approach
cd your-workflow-directory
bundle exec /path/to/roast/exe/roast execute workflow.yml target_file.rb

# ⚠️ May cause resource resolution issues
bundle exec roast execute /full/path/to/workflow.yml /full/path/to/target.rb
```

**Step Configuration**: Remember to add `print_response: true` to steps where you want to save output:

```yaml
steps:
  - analyze_code
  - generate_report

# Step configurations
analyze_code:
  print_response: true
generate_report:
  print_response: true
```

## Advanced Configuration Examples

### Production Workflow

```yaml
name: Production Grade Workflow
model: gpt-4o
context_management:
  enabled: true
  threshold: 0.75                           # Reasonable trigger point
  strategy: llm_summarization               # Better context preservation
  post_compaction_threshold_buffer: 0.85    # Balanced buffer
  summarization_model: gpt-4o-mini          # Fast, reliable model
  max_tokens: 128000                        # Explicit limit
  character_to_token_ratio: 0.25            # Conservative ratio
```

### Development/Testing Workflow

```yaml
name: Development Testing
model: gpt-4o-mini
context_management:
  enabled: true
  threshold: 0.5                            # Trigger early for testing
  strategy: truncation                      # Fast for development
  post_compaction_threshold_buffer: 0.8     # Standard buffer
```

### Cost-Optimized Workflow

```yaml
name: Cost Optimized Processing
model: gemini-2.0-flash
context_management:
  enabled: true
  threshold: 0.8
  strategy: llm_summarization
  summarization_model: gemini-2.0-flash     # Same model (already cheap)
  post_compaction_threshold_buffer: 0.9     # Minimize compaction frequency
```

## Best Practices

1. **Start with truncation strategy** for initial testing and development
2. **Use llm_summarization** for production workflows where context quality matters
3. **Set threshold between 0.7-0.8** for most use cases
4. **Monitor DEBUG output** to understand compaction behavior
5. **Test with your specific content** to optimize settings
6. **Use faster models for summarization** to minimize performance impact
7. **Adjust buffer based on workflow needs** - more buffer for bursty token usage

## Example Commands

```bash
# Basic test
bin/roast examples/context-test.yml

# With debug logging
DEBUG=1 bin/roast examples/large-analysis.yml

# Test specific configuration
bin/roast -c context_management.threshold=0.5 examples/workflow.yml
```

This feature makes Roast suitable for complex, long-running AI workflows that would otherwise hit context limits. Experiment with the provided examples to understand how it works with your specific use cases.