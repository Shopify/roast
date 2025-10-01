# typed: false
# frozen_string_literal: true

#### cmd

# Passing just the command to execute will run it and return the output
cmd <<~SHELLSTEP
  echo "raw run without storing, should see me once""
SHELLSTEP

# Passing a name finds or creates an object and returns that
cmd_cog = cmd(:hello)
puts "This is our new cmd_cog named ':hello': #{cmd_cog}"

# We can set a command to run for later
cmd(:set_and_run).set("echo 'set_and_run, should see me once'")
cmd(:set_and_run).run

# Similarly, we can run immediately and then re-run later
cmd(:run_and_rerun).run("echo 'run_and_rerun, should see me twice'")
cmd(:run_and_rerun).run

#### graph

# We can open and re-open a graph, and then execute it
graph(:updatable) do |graph|
  graph.node(:open_cmd) do |state|
    state[:open] = cmd("echo 'From a node added in first open, should see me once'")
  end
end

graph(:updatable) do |graph|
  graph.node(:reopen_cmd) do |state|
    state[:reopen] = cmd("echo 'From a node added in reopen, should see me once'")
  end
end

graph(:yea).execute

# We can also just populate and execute a graph in one go by calling graph.execute in the block.
graph(:define_and_exec) do |graph|
  graph.node(:hi) do |state|
    state[:hi_msg] = cmd("echo 'hi msg'")
  end

  graph.execute
end

# We can have subgraphs, because why not
graph(:outer) do |graph|
  graph.subgraph(:inner) do |subgraph|
    subgraph.node(:inner_node) do |inner_state|
      inner_state[:foo] = cmd("echo 'inner_state foo'")
    end
  end

  graph.node(:outer) do |outer_state|
    outer_state[:bar] = cmd("echo 'outer_state bar'")
  end

  graph.execute
end

# We can specify our own edges
graph(:edges) do |graph|
  graph.node(:thing1) do |state|
    state[:thing1] = cmd("echo 'thing1'")
  end

  graph.node(:thing2) do |state|
    state[:thing2] = cmd("echo 'thing2'")
  end

  graph.edge(from: :START, to: :thing1)
  graph.edge(from: :thing1, to: :thing2)
  graph.edge(from: :thing2, to: :DONE)

  graph.execute
end

# We can have parallel execution
graph(:parallel) do |graph|
  graph.node(:thing1) do |state|
    state[:thing1] = cmd("sleep 0.5 && echo 'parallel thing1'")
  end

  graph.node(:thing2) do |state|
    state[:thing2] = cmd("sleep 0.5 && echo 'parallel thing2'")
  end

  graph.edge(from: :START, to: [:thing1, :thing2])
  graph.edge(from: [:thing1, :thing2], to: :DONE)

  graph.execute
end

# We can have edges that are defined with a block
graph(:quantum) do |graph|
  graph.node(:thing1) do |state|
    state[:thing1] = cmd("echo 'quantum thing1'")
  end

  graph.edge(from: :START) do |_state|
    :thing1
  end

  graph.edge(from: :thing1) do |_state|
    :DONE
  end

  graph.execute
end
