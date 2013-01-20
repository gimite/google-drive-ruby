# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_drive/basic_fetcher"


module GoogleDrive

    class ClientLoginFetcher < BasicFetcher #:nodoc:
        
        def initialize(auth_tokens, proxy)
          super(proxy)
          @auth_tokens = auth_tokens
        end
        
        attr_accessor(:auth_tokens)
        
      private
        
        def auth_header(auth)
          token = auth == :none ? nil : @auth_tokens[auth]
          if token
            return {"Authorization" => "GoogleLogin auth=#{token}"}
          else
            return {}
          end
        end

    end
    
end
