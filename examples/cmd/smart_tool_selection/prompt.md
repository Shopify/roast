# Intelligent Tool Selection Examples

Based on the command descriptions, here's how I choose the right tool for different tasks:

## Task: "Check if our API is working"

I would use `curl` to "make HTTP requests":
Using `curl(args: "-I https://api.github.com")`:

## Task: "Extract data from API response"

First, I'd get data with `curl`, then use `jq` to "process JSON data":
Using `curl(args: "-s https://api.github.com/users/github") | jq(args: ".name, .company")`:

## Task: "See what containers are running"

I'd use `docker` (the "container platform"):
Using `docker(args: "ps --format 'table {{.Names}}\t{{.Status}}'")`:

## Task: "Check project dependencies"

For a Node.js project, I'd use `npm` (the "Node.js package manager"):
Using `npm(args: "list --depth=0")`:

## Task: "Run build tasks"

I'd use `make` to "run build targets":
Using `make(args: "--dry-run")`:

## The Power of Descriptions

Notice how each description helps me understand:
- **What** the tool does (primary function)
- **When** to use it (appropriate context)
- **How** to use it (command syntax and common options)

This leads to more accurate tool selection and better workflow outcomes!
