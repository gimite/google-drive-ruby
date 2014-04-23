# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "net/https"
require "uri"
Net::HTTP.version_1_2


module GoogleDrive

    class BasicFetcher #:nodoc:
        
        def initialize(proxy)
          if proxy
            @proxy = proxy
          elsif ENV["http_proxy"] && !ENV["http_proxy"].empty?
            proxy_url = URI.parse(ENV["http_proxy"])
            @proxy = Net::HTTP.Proxy(proxy_url.host, proxy_url.port)
          else
            @proxy = Net::HTTP
          end
        end
        
        def request_raw(method, url, data, extra_header, auth)
          uri = URI.parse(url)
          http = @proxy.new(uri.host, uri.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          # No timeout. It can take long e.g., when it tries to fetch a large file.
          http.read_timeout = nil
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
          return {}
        end

    end
    
end
