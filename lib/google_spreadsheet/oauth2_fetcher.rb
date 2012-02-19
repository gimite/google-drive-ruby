# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "rubygems"
require "oauth2"


module GoogleSpreadsheet

    class OAuth2Fetcher #:nodoc:
        
        Response = Struct.new(:code, :body)
        
        def initialize(oauth2_token)
          @oauth2_token = oauth2_token
        end
        
        def request_raw(method, url, data, extra_header, auth)
          if method == :delete || method == :get
            raw_res = @oauth2_token.request(method, url, {:header => extra_header})
          else
            raw_res = @oauth2_token.request(method, url, {:header => extra_header, :body => data})
          end
          return Response.new(raw_res.status.to_s(), raw_res.body)
        end
        
    end
    
end
