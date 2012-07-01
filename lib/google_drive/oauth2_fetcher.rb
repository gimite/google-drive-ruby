# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "rubygems"
require "oauth2"


module GoogleDrive

    class OAuth2Fetcher #:nodoc:
        
        class Response
            
            def initialize(raw_res)
              @raw_res = raw_res
            end
            
            def code
              return @raw_res.status.to_s()
            end
            
            def body
              return @raw_res.body
            end
            
            def [](name)
              return @raw_res.headers[name]
            end
            
        end
        
        def initialize(oauth2_token)
          @oauth2_token = oauth2_token
        end
        
        def request_raw(method, url, data, extra_header, auth)
          if method == :delete || method == :get
            raw_res = @oauth2_token.request(method, url, {:headers => extra_header})
          else
            raw_res = @oauth2_token.request(method, url, {:headers => extra_header, :body => data})
          end
          return Response.new(raw_res)
        end
        
    end
    
end
