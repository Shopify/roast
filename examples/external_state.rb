# typed: true
# frozen_string_literal: true

require "json"

#: self as Roast::Workflow

execute do
  ruby(:state) do
    path = ENV.fetch("ROAST_STATE_FILE")

    case ENV.fetch("ROAST_STATE_ACTION", "recall")
    when "save"
      selected_fact = { checklist: "Run the synthetic smoke check before packaging." }
      File.write(path, JSON.generate(selected_fact))
      { status: "saved" }
    when "recall"
      begin
        { status: "found", value: JSON.parse(File.read(path)) }
      rescue Errno::ENOENT
        { status: "abstain" }
      end
    else
      raise ArgumentError, "ROAST_STATE_ACTION must be save or recall"
    end
  end

  ruby(:report) do
    puts JSON.generate(ruby!(:state).value)
  end
end
