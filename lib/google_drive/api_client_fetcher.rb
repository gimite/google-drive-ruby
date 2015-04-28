# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "net/https"
require "uri"
Net::HTTP.version_1_2


module GoogleDrive

    class ApiClientFetcher
        
        class Response

            def initialize(client_response)
              @client_response = client_response
            end

            def code
              return @client_response.status.to_s()
            end

            def body
              return @client_response.body
            end

            attr_reader(:client_response)

        end

        def initialize(client)
          @client = client
          # Sets virtually infinite default timeout because some operations (e.g., uploading
          # a large files/spreadsheets) can take very long.
          @client.connection.options[:timeout] ||= 100000000
          @drive = @client.discovered_api("drive", "v2")
        end

        attr_reader(:client, :drive)
        
        def request_raw(method, url, data, extra_header, auth)
          client_response = @client.execute(
              :http_method => method,
              :uri => url,
              :body => data,
              :headers => extra_header)
          return Response.new(client_response)
        end
        
    end
    
end
