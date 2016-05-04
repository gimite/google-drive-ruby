# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require 'net/https'
require 'uri'
require 'google/apis/drive_v3'
Net::HTTP.version_1_2

module GoogleDrive
  class ApiClientFetcher
    class Response
      def initialize(code, body)
        @code = code
        @body = body
      end

      attr_reader(:code, :body)
    end

    def initialize(authorization)
      @drive = Google::Apis::DriveV3::DriveService.new
      @drive.authorization = authorization
    end

    attr_reader(:drive)

    def request_raw(method, url, data, extra_header, _auth)
      options = Google::Apis::RequestOptions.default.merge(header: extra_header)
      body = @drive.http(method, url, body: data, options: options)
      Response.new('200', body)
    end
  end
end
