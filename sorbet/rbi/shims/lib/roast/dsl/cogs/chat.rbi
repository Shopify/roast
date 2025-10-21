# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Chat
        class Config
          #: (?String?) -> String?
          def model(value = nil); end
          #: (?String?) -> String?
          def api_key(value = nil); end
          #: (?String?) -> String?
          def base_url(value = nil); end
          #: (?Symbol?) -> Symbol?
          def provider(value = nil); end
          #: (?bool?) -> bool?
          def assume_model_exists(value = nil); end
        end
      end
    end
  end
end
