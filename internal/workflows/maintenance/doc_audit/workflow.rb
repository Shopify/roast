# typed: false
# frozen_string_literal: true

#: self as Roast::Workflow

# Guards against doc comment drift by treating a single doc-comment block (the contiguous `#`
# prose above a definition) as the atomic unit of audit. It enumerates the in-scope doc comments
# (see Targets below), asks an agent to verify each one in isolation against the real
# implementation, groups the stale ones into a single PR, and opens it only when the `apply` flag
# is passed. Without `apply` it is read-only: it prints the findings and opens nothing.
#
# Parameters:
#   apply   open PRs instead of only reporting (default: off / dry-run).
#
#   Targets: pass one or more files or directories to audit only those (a directory is expanded to
#            its `.rb`/`.rbi` files); with no target it audits the full default scope, `lib/roast/**/*.rb`
#            plus the user-facing rbi shims.
#
# Read-only (dry-run) runs from any branch and audits the working tree as-is. `apply` opens the PR
# on top of the branch it is run from: from `main` the fix stacks cleanly on `main`; from a feature
# branch it stacks on that branch. `apply` requires a clean working tree and the current branch to be
# pushed and even with its origin counterpart, so the PR diff is only the doc fix.
#
# Examples:
#   # dry-run the full default scope (prints findings, opens nothing, writes nothing):
#   bin/roast execute internal/workflows/doc_audit/workflow.rb
#
#   # dry-run only a directory or a single file (shell globs are expanded too):
#   bin/roast execute internal/workflows/doc_audit/workflow.rb lib/roast/cog
#   bin/roast execute internal/workflows/doc_audit/workflow.rb lib/roast/cog/output.rb
#
#   # open the PR of fixes on top of the current branch:
#   bin/roast execute internal/workflows/doc_audit/workflow.rb -- apply
#
#   # scope the audit and apply in one run:
#   bin/roast execute internal/workflows/doc_audit/workflow.rb lib/roast/cog -- apply

config do
  agent(:judge) do
    provider :claude
    model "sonnet"
    quiet!
  end

  # Each unit verification is independent, we can run them in parallel.
  map(:verify_units) do
    parallel(8)
  end
end

execute do
  # When `apply` is set, verify up front that the PR can be opened on top of the current branch, before
  # spending the heavy enumerate/verify work. Dry-run skips this and audits the working tree from any branch.
  ruby(:preflight) do
    skip! unless arg?(:apply)

    current = %x(git rev-parse --abbrev-ref HEAD).strip
    # Apply opens the PR against the current branch, so a detached HEAD has no branch name to target.
    fail!("run `-- apply` from a branch, not detached HEAD") if current == "HEAD"
    # Apply mutates the working tree (checkout/commit/checkout back), so it needs a clean working tree.
    fail!("working tree is dirty; commit or stash before running with `-- apply`") unless %x(git status --porcelain).strip.empty?
    # The PR stacks on the current branch, so its origin counterpart must exist and equal local HEAD,
    # otherwise the diff would carry unpushed commits (or `gh pr create` would have no base to target).
    system("git", "fetch", "origin", current, out: File::NULL, err: File::NULL)
    local = %x(git rev-parse HEAD).strip
    remote = IO.popen(["git", "rev-parse", "--verify", "--quiet", "origin/#{current}"], err: File::NULL, &:read).strip
    fail!("branch `#{current}` must be pushed and even with `origin/#{current}` before `-- apply`") unless !remote.empty? && local == remote
  end

  # Phase 1: enumerate atomic doc-comment units using prism.
  ruby(:enumerate) do
    require "prism"

    # The scope: any files/directories passed as targets (a directory is expanded to its Ruby
    # sources), or the full default scope: every .rb file under lib/roast plus our rbi shims.
    scope_files =
      if targets.any?
        targets.flat_map { |t| File.directory?(t) ? Dir.glob(File.join(t, "**/*.{rb,rbi}")) : [t] }.uniq.sort
      else
        (Dir.glob("lib/roast/**/*.rb") + Dir.glob("sorbet/rbi/shims/**/*.rbi")).uniq.sort
      end

    # Comment patterns that are never human prose and must not be counted as part of a doc block.
    magic = /\A#\s*(?:typed|frozen_string_literal|encoding|warn_indent|shareable_constant_value):/
    sig = /\A#[:|]/ # RBS inline signature: the `#:` opener plus its `#|` continuation lines.
    rubocop = /\A#\s*rubocop:/
    directive = /\A#\s*@\w+:/ # RBS annotation directives, e.g. `# @requires_ancestor:`.

    # Accumulates one hash per documented definition, across every file in scope.
    units = []

    scope_files.each do |file|
      # Read and parse the file using prism.
      source = File.read(file)
      lines = source.lines.map(&:chomp)
      result = Prism.parse(source)

      # Mark every line Prism considers part of a comment.
      comment_line = {}
      result.comments.each do |c|
        (c.location.start_line..c.location.end_line).each { |ln| comment_line[ln] = true }
      end

      # Helper lambdas to analyze the lines of the file. All line numbers are 1-based.
      # Returns the line text, left-stripped.
      body = ->(ln) { (lines[ln - 1] || "").lstrip }

      # Checks if the line is a real comment line, excluding inline trailing comments.
      doc = ->(ln) { comment_line[ln] && body.call(ln).start_with?("#") }

      # Checks if the line is a bare `#`.
      blank = ->(ln) { body.call(ln).match?(/\A#\s*\z/) }

      # Checks if the line is a magic/directive line.
      hard = ->(ln) { body.call(ln).match?(magic) || body.call(ln).match?(directive) }

      # Captures the prose block above the anchor (definition line): skip the sig/rubocop/blank zone directly above the def,
      # then collect contiguous comment lines up to the first hard separator. Returns [start, end]
      # (1-based, inclusive) or nil when there is no prose.
      region = lambda do |anchor|
        # Line starts at anchor - 1 (definition line - 1).
        ln = anchor - 1
        # While we are still in the bounds of the doc and the line is either a sig, rubocop, or blank line, keep moving up.
        while ln >= 1 && doc.call(ln) &&
            (body.call(ln).match?(sig) || body.call(ln).match?(rubocop) || blank.call(ln))
          ln -= 1
        end
        # After the while loop completes, ln is now at the last possible line of the prose block.
        prose_end = ln
        # Keep moving up while still in the doc block and the line is neither a hard separator nor a
        # sig/rubocop line (loop 1 only cleared the sig/rubocop/blank zone directly above the def).
        while ln >= 1 && doc.call(ln) && !hard.call(ln) &&
            !body.call(ln).match?(sig) && !body.call(ln).match?(rubocop)
          ln -= 1
        end
        # After the while loop completes, ln + 1 is now at the first possible line of the prose block.
        prose_start = ln + 1
        # Trim leading blank `#` lines off the top of the block.
        prose_start += 1 while prose_start <= prose_end && blank.call(prose_start)
        # Start would be greater than end if the block is empty, so return nil in that case.
        prose_start <= prose_end ? [prose_start, prose_end] : nil
      end

      # Record one audit unit for a definition: find its prose block and, when it has one, capture
      # the file, fully-qualified symbol, kind, line span, RBS signature and the comment text.
      emit = lambda do |anchor, symbol, kind|
        # calls region to find the prose block above the anchor (definition line).
        bounds = region.call(anchor)
        # If there is no prose, skip this definition.
        next if bounds.nil?

        # Capture the prose block's start and end lines.
        s, e = bounds
        # Look through the lines between the end of the prose block and the anchor for any RBS inline signature lines, and collect them.
        sig_lines = ((e + 1)...anchor).select { |ln| doc.call(ln) && body.call(ln).match?(sig) }.map { |ln| body.call(ln) }
        # Capture the unit's file, symbol, kind, start/end lines, signature (if any), and comment text into the units array.
        units << {
          file: file,
          symbol: symbol,
          kind: kind,
          start_line: s,
          end_line: e,
          signature: sig_lines.empty? ? nil : sig_lines.join("\n"),
          comment_text: lines[(s - 1)..(e - 1)].join("\n"),
        }
      end

      # Recursively walk the AST; this is what drives emission. Each branch handles a form that a doc comment can sit above.
      walk = nil
      walk = lambda do |node, ns, singleton|
        return if node.nil?

        case node
          # When Prism sees a program, it has a list of statements; recurse into them.
        when Prism::ProgramNode
          walk.call(node.statements, ns, singleton)
          # When Prism sees a list of statements, recurse into each one.
        when Prism::StatementsNode
          node.body.each { |child| walk.call(child, ns, singleton) }
          # When Prism sees a module or class, emit it and recurse into its body.
        when Prism::ModuleNode, Prism::ClassNode
          name = node.constant_path.slice
          full = ns.empty? ? name : "#{ns}::#{name}"
          kind = node.is_a?(Prism::ModuleNode) ? "module" : "class"
          emit.call(node.location.start_line, full, kind)
          walk.call(node.body, full, false)
          # When Prism sees a singleton class, recurse into its body.
        when Prism::SingletonClassNode
          walk.call(node.body, ns, true)
        when Prism::DefNode
          # When Prism sees a method definition, emit it.
          sep = singleton || !node.receiver.nil? ? "." : "#"
          emit.call(node.location.start_line, "#{ns}#{sep}#{node.name}", "method")
          # When Prism sees a constant assignment, emit it.
        when Prism::ConstantWriteNode
          prefix = ns.empty? ? "" : "#{ns}::"
          emit.call(node.location.start_line, "#{prefix}#{node.name}", "constant")
          # When Prism sees an attribute assignment, emit it.
        when Prism::CallNode
          if node.receiver.nil? && [:attr_reader, :attr_writer, :attr_accessor].include?(node.name)
            names = (node.arguments&.arguments || [])
              .select { |a| a.is_a?(Prism::SymbolNode) }.map(&:unescaped)
            emit.call(node.location.start_line, names.map { |n| "#{ns}##{n}" }.join(", "), "attr") unless names.empty?
          end
        end
      end

      # Start the walk at the file root; the recursion fills in `units`.
      walk.call(result.value, "", false)
    end

    # Return every enumerated unit.
    units
  end

  # Phase 2: verify each unit in isolation (map + agent, runs in parallel).
  # Goes over the enumerated units, running the :verify_one scope once per unit.
  # The verdicts are read back in Phase 3.
  map(:verify_units, run: :verify_one) do
    ruby!(:enumerate).value
  end

  # Phase 3: classify each verdict into fixable, low-confidence, or factual.
  ruby(:plan) do
    # Collect one verdict per unit.
    verdicts = collect(map!(:verify_units)) { |verdict, _unit, _idx| verdict }.compact

    # A verdict is auto-fixed only if the agent is confident it is wrong and its fix is safe to apply.
    # A fix is considered usable (safe to apply) if it is non-empty and every line starts with `#` (after stripping whitespace).
    usable = lambda do |v|
      fix = v[:suggested_fix].to_s.strip
      !fix.empty? && fix.lines.all? { |l| l.strip.start_with?("#") }
    end
    failing = []
    low_confidence = []
    ok = 0
    # Checks each verdict: if factual, count it as ok; if flagged, confident and usable, count it as failing; otherwise count it as low-confidence.
    verdicts.each do |v|
      if v[:factual]
        ok += 1
      elsif v[:confidence].to_f >= 0.8 && usable.call(v) # 0.8 = min confidence to auto-fix; below it is report-only
        failing << v
      else
        low_confidence << v
      end
    end

    counts = { checked: verdicts.size, ok: ok, failing: failing.size, low_confidence: low_confidence.size }

    # Returns the fixable findings, the counts, and the low-confidence findings.
    {
      failing: failing,
      counts: counts,
      low_confidence: low_confidence,
    }
  end

  # Phase 4: apply + open PRs (only runs when `-- apply` is passed).
  ruby(:apply) do
    skip! unless arg?(:apply)
    require "shellwords"

    plan = ruby!(:plan).value
    failing = plan[:failing]
    base = %x(git rev-parse HEAD).strip
    base_short = base[0, 10]
    original = %x(git rev-parse --abbrev-ref HEAD).strip
    opened = nil

    # Index the failing verdicts by file to shape the PR body (one section per file) and, below, batches
    # each file's fixes for splicing.
    by_file = failing.group_by { |v| v[:unit][:file] }
    files = by_file.keys.sort
    # Builds the PR body: one section per file, one bullet per stale doc comment, with its confidence and issues.
    body = +"Automated doc-comment audit on top of `#{original}` (base `#{base_short}`).\n\n"
    files.each do |file|
      body << "### `#{file}`\n\n"
      by_file[file].each do |v|
        body << "- **#{v[:unit][:symbol]}** (confidence #{v[:confidence]})\n"
        Array(v[:issues]).each { |issue| body << "  - #{issue}\n" }
        body << "  - evidence: #{v[:evidence]}\n" if v[:evidence]
      end
      body << "\n"
    end
    # Builds the PR plan. The PR is opened on top of the current branch (`original`); the doc-audit
    # branch is named per source branch so re-running from it updates the same PR.
    pr_plan =
      if failing.empty?
        []
      else
        [{
          id: base_short,
          base: original,
          branch: "doc-audit/#{original.tr("/", "-")}",
          title: "Fix #{failing.size} stale doc comment(s) across #{files.size} file(s)",
          body: body,
          files: files,
          verdicts: failing,
        }]
      end

    # Build the corrected file contents by splicing each fix in, bottom-to-top so earlier line
    # numbers stay valid.
    changed = {}
    by_file.each do |file, verds|
      lines = File.read(file).lines
      verds.sort_by { |v| -v[:unit][:start_line] }.each do |v|
        u = v[:unit]
        # Re-indent the suggested fix to match the original block's indentation, then splice it in.
        indent = (lines[u[:start_line] - 1] || "")[/\A\s*/]
        replacement = v[:suggested_fix].to_s.split("\n").map { |l| "#{indent}#{l.sub(/\A\s+/, "")}\n" }
        lines[(u[:start_line] - 1)...u[:end_line]] = replacement
      end
      changed[file] = lines.join
    end

    # Restore the original branch on exit, whether the loop completes or raises.
    begin
      pr_plan.each do |pr|
        files = pr[:files]

        # Deterministic branch name; check whether a PR for it already exists.
        branch = pr[:branch]
        existing = %x(gh pr list --head #{Shellwords.escape(branch)} --json url --jq ".[0].url" 2>/dev/null).strip

        # Cut the branch from the pinned base, write the corrected files, commit, and push. Abort on
        # any git failure so a partial or wrong result never looks like success.
        unless system("git", "checkout", "-B", branch, base, out: File::NULL, err: File::NULL)
          fail!("could not create branch `#{branch}` from #{base_short}")
        end
        files.each { |p| File.write(p, changed[p]) }
        system("git", "add", *files)
        # `git commit` exits non-zero when nothing is staged (a fix that re-indents to the original);
        # treat that as a no-op and skip the push/PR instead of opening an empty PR.
        next unless system("git", "commit", "-m", pr[:title], out: File::NULL, err: File::NULL)

        unless system("git", "push", "-u", "origin", branch, "--force-with-lease", out: File::NULL, err: File::NULL)
          fail!("could not push `#{branch}` to origin")
        end

        # Open a fresh PR, or note that we refreshed the branch of an existing one.
        if existing.empty?
          body_file = tmpdir.join("pr_body_#{pr[:id]}.md")
          File.write(body_file, pr[:body])
          create = ["gh", "pr", "create", "--draft", "--base", pr[:base], "--head", branch, "--title", pr[:title], "--body-file", body_file.to_s]
          opened = %x(#{Shellwords.join(create)} 2>&1).strip
        else
          opened = "#{existing} (branch updated)"
        end
      end
    ensure
      system("git", "checkout", original, out: File::NULL, err: File::NULL)
    end

    opened
  end

  # Phase 5: user-facing summary
  ruby(:summary) do
    plan = ruby!(:plan).value
    counts = plan[:counts]

    puts "\n=== Doc-comment audit ==="
    puts "checked: #{counts[:checked]}\n" \
      "factual: #{counts[:ok]}  \n" \
      "stale (auto-fixable): #{counts[:failing]}\n" \
      "low-confidence (not auto-fixable): #{counts[:low_confidence]}"
    # Stale comments to fix, grouped by file, with the specific issues found.
    unless plan[:failing].empty?
      puts "stale comments to fix (#{counts[:failing]}):"
      plan[:failing].group_by { |v| v[:unit][:file] }.sort.each do |file, verds|
        puts "  #{file}"
        verds.each do |v|
          puts "    · #{v[:unit][:symbol]}  (confidence #{v[:confidence]})"
          Array(v[:issues]).each { |issue| puts "        - #{issue}" }
        end
      end
    end

    # Low-confidence findings are surfaced for a human but never auto-fixed.
    unless plan[:low_confidence].empty?
      puts "low-confidence findings (reported only, not auto-fixed):"
      plan[:low_confidence].each do |v|
        puts "  · #{v[:unit][:symbol]} in #{v[:unit][:file]}  (confidence #{v[:confidence]})"
        Array(v[:issues]).each { |issue| puts "      - #{issue}" }
      end
    end

    # In apply mode, print the single PR URL, or state that there was nothing to open.
    if arg?(:apply)
      url = ruby!(:apply).value
      if url
        puts "opened / updated PR: #{url}"
      else
        puts "no stale doc comments; nothing to open."
      end
    else
      puts "(dry-run; no PRs opened, pass `-- apply` to open them)"
    end
  end
end

# Named scope: verifies one atomic doc-comment unit
execute(:verify_one) do
  # Evaluates one unit at a time, returning a JSON.
  agent(:judge) do |_, unit|
    [
      template("verify_comment", { unit: unit }),
      "Now output ONLY the JSON verdict described above with no surrounding text.",
    ]
  end

  # The scope's return value. Parse the JSON verdict. If parsing fails, record a non-factual,
  # zero-confidence verdict so the unit is surfaced as report-only.
  outputs! do |unit, _idx|
    verdict =
      begin
        agent!(:judge).json!
      rescue => e
        { factual: false, issues: ["verdict could not be parsed: #{e.message}"], confidence: 0.0, suggested_fix: unit[:comment_text], parse_error: e.message }
      end
    verdict.merge(unit: unit)
  end
end
