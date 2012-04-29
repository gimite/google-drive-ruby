# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "rubygems"
require "oauth"


module GoogleDrive

    class OAuth1Fetcher #:nodoc:
        
        def initialize(oauth1_token)
          @oauth1_token = oauth1_token
        end
        
        def request_raw(method, url, data, extra_header, auth)
          if method == :delete || method == :get
            return @oauth1_token.__send__(method, url, extra_header)
          else
            return @oauth1_token.__send__(method, url, data, extra_header)
          end
        end
        
    end
    
end
