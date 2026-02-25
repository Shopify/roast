# typed: true
# frozen_string_literal: true

module Roast
  class Event
    class << self
      #: (Hash[Symbol, untyped]) -> void
      def <<(event)
        EventMonitor.accept(Event.new(TaskContext.path, event))
      end
    end

    LOG_TYPE_KEYS = [
      :fatal,
      :error,
      :warn,
      :info,
      :debug,
      :unknown,
    ].freeze #: Array[Symbol]

    OTHER_TYPE_KEYS = [
      :begin,
      :end,
      :stdout,
      :stderr,
    ].freeze #: Array[Symbol]

    #: Array[Symbol | Integer]
    attr_reader :path

    #: Hash[Symbol, untyped] :payload
    attr_reader :payload

    #: Time
    attr_reader :time

    delegate :[], :key?, :keys, to: :payload

    #: (Array[Symbol | Integer] path, Hash[Symbol, untyped]) -> void
    def initialize(path, payload)
      @path = path
      @payload = payload
      @time = Time.now
    end

    #: () -> Symbol
    def type
      return :log if (LOG_TYPE_KEYS & @payload.keys).present?

      (OTHER_TYPE_KEYS & @payload.keys).first || :unknown
    end

    #: () -> Integer
    def log_severity
      severity = case type
      when :log
        (LOG_TYPE_KEYS & @payload.keys).first || :unknown
      when :stderr
        :warn
      else
        :info
      end
      Logger::Severity.const_get(:LEVELS)[severity.to_s] # rubocop:disable Sorbet/ConstantsFromStrings
    end

    #: () -> String
    def log_message
      key = (LOG_TYPE_KEYS & @payload.keys).first
      return "" unless key.present?

      payload[key] || ""
    end
  end
end
