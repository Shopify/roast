Hello {{ENV['ROAST_NAME']}}! 

Welcome to the Roast MCP Server demo. This workflow was called via the Model Context Protocol.

The current time is: {{Time.now}}

{{if ENV['ROAST_MESSAGE']}}
Your message: {{ENV['ROAST_MESSAGE']}}
{{end}}