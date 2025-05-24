# frozen_string_literal: true

class InfoFromRoast < Roast::Workflow::BaseStep
  def call
    examples_path = File.join(Roast::ROOT, "examples")
    tools_path = File.join(Roast::ROOT, "lib", "roast", "tools")

    # Get list of available tools
    available_tools = Dir.entries(tools_path)
      .select { |file| file.end_with?(".rb") }
      .map { |file| file.gsub(".rb", "") }
      .reject { |tool| tool == "." || tool == ".." }
      .sort

    {
      examples_directory: examples_path,
      tools_directory: tools_path,
      available_tools: available_tools,
      message: "Examples directory and available tools provided for analysis step",
    }
  end
end
