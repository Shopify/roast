# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

# By default, Roast logs to standard error at the WARN level. You can easily override this with the ROAST_LOG_LEVEL
# environment variable, without having to touch the logger's configuration itself.
#   Valid levels are DEBUG, INFO, WARN, ERROR, or FATAL (not case-sensitive).
# For more advanced configuration, such as configuring a custom log formatter, or logging to a custom output location,
# you can configure ore replace  the logger instance used by Roast (Roast::Log.logger)

# Log to standard output, always at the DEBUG level
Roast::Log.logger = Logger.new($stdout).tap { |logger| logger.level = ::Logger::DEBUG }

# Format log lines in a particular way
Roast::Log.logger.formatter = proc do |severity, time, progname, msg|
  "#{severity[0..0]}, #{msg.strip} (at #{time})\n"
end


config do
  cmd(:echo) { display! }
end

execute do
  cmd(:echo) { "echo hello world" }
end
