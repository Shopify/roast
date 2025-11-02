# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        module Providers
          class Claude < Provider
            module Messages
              class ResultMessage < Message
                #: String
                attr_reader :content

                #: bool
                attr_reader :success

                #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
                def initialize(type:, hash:)
                  subtype = hash.delete(:subtype)
                  @content = hash.delete(:result) || ""
                  @success = hash.delete(:success) || subtype == "success"
                  if hash.delete(:is_error) || subtype == "error"
                    @content = @content || hash.dig(:error, :message) || "Unknown error"
                    hash.delete(:error)
                  end
                  super(type:, hash:)
                end
              end
            end
          end
        end
      end
    end
  end
end
