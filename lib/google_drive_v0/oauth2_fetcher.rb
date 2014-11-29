# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_drive_v0/basic_fetcher"


module GoogleDriveV0

    class OAuth2Fetcher < BasicFetcher #:nodoc:
        
        def initialize(auth_token, proxy)
          super(proxy)
          @auth_token = auth_token
        end
        
      private

        def auth_header(auth)
          return {"Authorization" => "Bearer %s" % @auth_token}
        end

    end
    
end
