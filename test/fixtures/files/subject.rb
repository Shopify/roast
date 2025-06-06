#!/usr/bin/env ruby
# frozen_string_literal: true

module Roast
  extend self

  ROAST_ROOT = File.dirname(__FILE__)

  class CLI < Thor
    register(Roast::Commands::TestCommand, "test", "test", "Grade a test")
  end
end
