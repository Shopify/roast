# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          class Message
            IGNORED_FIELDS = [
              :uuid,
            ].freeze

            class << self
              #: (String, ?raw_dump_file: Pathname?) -> Message
              def from_json(json, raw_dump_file: nil)
                raw_dump_file&.dirname&.mkpath
                File.write("./tmp/claude-messages.log", "#{json}\n", mode: "a") if raw_dump_file
                from_hash(JSON.parse(json, symbolize_names: true))
              end

              #: (Hash[Symbol, untyped]) -> Message
              def from_hash(hash)
                type = hash.delete(:type)&.to_sym
                message_class = resolve_message_class(type)
                message_class.new(type:, hash:)
              end

              private

              #: (Symbol?) -> singleton(Message)
              def resolve_message_class(type)
                return Messages::UnknownMessage if type.nil?

                class_name = "#{type}_message".camelize
                if Messages.const_defined?(class_name, false)
                  Messages.const_get(class_name, false) # rubocop:disable Sorbet/ConstantsFromStrings
                else
                  Messages::UnknownMessage
                end
              rescue NameError
                Messages::UnknownMessage
              end
            end

            #: String?
            attr_reader :session_id

            #: Symbol
            attr_reader :type

            #: String?
            attr_reader :error

            #: Hash[Symbol, untyped]
            attr_reader :unparsed

            #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
            def initialize(type:, hash:)
              @session_id = hash.delete(:session_id)
              @type = type
              @error = hash.delete(:error)
              hash.except!(*IGNORED_FIELDS)
              @unparsed = hash
            end

            #: (ClaudeInvocation::Context) -> String?
            def format(context)
            end
          end
        end
      end
    end
  end
end
