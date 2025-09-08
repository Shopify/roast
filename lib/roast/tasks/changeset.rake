# typed: false
# frozen_string_literal: true

namespace :changeset do
  desc "Add a new changeset for version bumping"
  task :add do
    require "fileutils"
    require "cli/ui"

    CLI::UI::Frame.open("Creating Changeset") do
      # Get version bump type
      type = CLI::UI::Prompt.ask("What type of change is this?") do |handler|
        handler.option("patch") { "patch" }
        handler.option("minor") { "minor" }
        handler.option("major") { "major" }
      end

      # Get description
      description = CLI::UI::Prompt.ask("Enter a brief description of the changes:")

      # Generate unique filename based on timestamp and random string
      timestamp = Time.now.strftime("%Y%m%d%H%M%S")
      random_str = SecureRandom.hex(3)
      filename = ".changeset/#{timestamp}-#{random_str}.md"

      # Create changeset file
      File.write(filename, <<~CONTENT)
        ---
        type: #{type}
        ---

        #{description}
      CONTENT

      CLI::UI::Frame.divider("Success")
      puts CLI::UI.fmt("{{v}} Created changeset: {{cyan:#{filename}}}")
      puts ""
      puts "Your changeset has been created. It will be included in the next release."
      puts ""

      # Show what version bump this will cause
      case type
      when "patch"
        puts "This will trigger a patch version bump (0.0.X)"
      when "minor"
        puts "This will trigger a minor version bump (0.X.0)"
      when "major"
        puts "This will trigger a major version bump (X.0.0)"
      end
    end
  end

  desc "List pending changesets"
  task :list do
    require "cli/ui"

    changesets = Dir.glob(".changeset/*.md").reject { |f| f.end_with?("README.md") }

    if changesets.empty?
      CLI::UI::Frame.open("No Pending Changesets") do
        puts "There are no pending changesets."
        puts "Run 'bundle exec rake changeset:add' to create one."
      end
    else
      CLI::UI::Frame.open("Pending Changesets (#{changesets.count})") do
        changesets.each do |file|
          content = File.read(file)

          # Extract type from frontmatter
          type = begin
            content.match(/type:\s*(\w+)/)[1]
          rescue
            "unknown"
          end

          # Extract description (content after frontmatter)
          description = content.split("---", 3).last.strip.lines.first&.strip || "No description"

          # Color code by type
          type_display = case type
          when "major"
            CLI::UI.fmt("{{red:#{type}}}")
          when "minor"
            CLI::UI.fmt("{{yellow:#{type}}}")
          when "patch"
            CLI::UI.fmt("{{green:#{type}}}")
          else
            type
          end

          filename = File.basename(file)
          puts CLI::UI.fmt("{{bold:#{filename}}} [#{type_display}]: #{description}")
        end

        # Determine what version bump will happen
        types = changesets.map do |f|
          File.read(f).match(/type:\s*(\w+)/)[1]
        rescue
          nil
        end.compact

        bump_type = if types.include?("major")
          "major"
        elsif types.include?("minor")
          "minor"
        else
          "patch"
        end

        CLI::UI::Frame.divider("Next Release")

        current_version = Roast::VERSION
        major, minor, patch = current_version.split(".").map(&:to_i)

        new_version = case bump_type
        when "major"
          "#{major + 1}.0.0"
        when "minor"
          "#{major}.#{minor + 1}.0"
        else
          "#{major}.#{minor}.#{patch + 1}"
        end

        puts CLI::UI.fmt("Current version: {{cyan:#{current_version}}}")
        puts CLI::UI.fmt("Next version will be: {{green:#{new_version}}} ({{bold:#{bump_type}}} bump)")
      end
    end
  end

  desc "Validate all pending changesets"
  task :validate do
    require "cli/ui"

    changesets = Dir.glob(".changeset/*.md").reject { |f| f.end_with?("README.md") }

    if changesets.empty?
      puts CLI::UI.fmt("{{v}} No changesets to validate")
      exit 0
    end

    errors = []

    changesets.each do |file|
      content = File.read(file)
      filename = File.basename(file)

      # Check for frontmatter
      unless content.include?("---")
        errors << "#{filename}: Missing frontmatter markers (---)"
        next
      end

      # Check for type field
      unless content.match?(/type:\s*(patch|minor|major)/)
        errors << "#{filename}: Invalid or missing 'type' field (must be patch, minor, or major)"
      end

      # Check for description
      description = content.split("---", 3).last.strip
      if description.empty?
        errors << "#{filename}: Missing description"
      end
    end

    if errors.empty?
      CLI::UI::Frame.open("Validation Passed", color: :green) do
        puts CLI::UI.fmt("{{v}} All #{changesets.count} changesets are valid")
      end
    else
      CLI::UI::Frame.open("Validation Failed", color: :red) do
        errors.each do |error|
          puts CLI::UI.fmt("{{x}} #{error}")
        end
      end
      exit 1
    end
  end
end
