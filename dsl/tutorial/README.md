![roast-horiz-logo](https://github.com/user-attachments/assets/f9b1ace2-5478-4f4a-ac8e-5945ed75c5b4)

# Roast Tutorial
🔥 _version 1.0 feature preview_ 🔥

Welcome to the Roast tutorial! This guide will teach you how to build AI workflows using the Roast DSL.

## What is Roast?

Roast is a Ruby-based domain-specific language for creating structured AI workflows
and building complex AI-powered automation. You write workflows in a simple Ruby syntax to orchestrate LLM calls,
run coding agents, process data, and so much more.

## Prerequisites

- Ruby installed (3.4.2+)
- Roast gem installed
- API keys for your AI providers of choice (to use LLM chat)
- Claude Code CLI installed and configured (to use coding agents)

## How to Use This Tutorial

Each chapter is a self-contained lesson with:

- **README.md** - Lesson content with explanations and code snippets
- **Workflow files** (`.rb`) - Complete, runnable examples
- **data/** folder - Sample data files (when needed)

To run any example:

```bash
bin/roast execute --executor=dsl dsl/tutorial/CHAPTER_NAME/workflow_name.rb
```

## Tutorial Chapters

### Chapter 1: Your First Workflow

Quickly learn the basics: how to create and run a simple workflow with a single chat cog.

**You'll learn:**

- Basic workflow file structure
- Using the `chat` cog
- Running workflows
- Simple configuration

**Files:**

- `01_your_first_workflow/hello.rb` - Simplest possible workflow
- `01_your_first_workflow/configured_chat.rb` - Adding configuration

---

### Coming Soon

Future chapters will cover:

- Chaining multiple cogs together
- Working with agent cogs for file access
- Configuration options
- Control flow (skip!, fail!)
- Creating reusable scopes
- Processing collections
- Iterative workflows

---

Let's get started with
[Chapter 1](https://github.com/Shopify/roast/blob/edge/dsl/tutorial/01_your_first_workflow/README.md)!
