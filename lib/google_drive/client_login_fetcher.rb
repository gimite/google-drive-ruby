# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "net/https"
require "uri"
Net::HTTP.version_1_2


module GoogleDrive

    class ClientLoginFetcher #:nodoc:
        
        def initialize(auth_tokens, proxy)
          @auth_tokens = auth_tokens
          if proxy
            @proxy = proxy
          elsif ENV["http_proxy"] && !ENV["http_proxy"].empty?
            proxy_url = URI.parse(ENV["http_proxy"])
            @proxy = Net::HTTP.Proxy(proxy_url.host, proxy_url.port)
          else
            @proxy = Net::HTTP
          end
        end
        
        attr_accessor(:auth_tokens)
        
        def request_raw(method, url, data, extra_header, auth)
          uri = URI.parse(url)
          http = @proxy.new(uri.host, uri.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          http.start() do
            path = uri.path + (uri.query ? "?#{uri.query}" : "")
            header = auth_header(auth).merge(extra_header)
            if method == :delete || method == :get
              return http.__send__(method, path, header)
            else
              return http.__send__(method, path, data, header)
            end
          end
        end
        
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
