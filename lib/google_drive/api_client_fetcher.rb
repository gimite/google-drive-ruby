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

      # Make the timeout virtually infinite because some of the operations
      # (e.g., uploading a large file) can take very long.
      # This value is the maximal allowed timeout in seconds on JRuby.
      t = (2**31 - 1) / 1000
      @drive.client_options.open_timeout_sec = t
      @drive.client_options.read_timeout_sec = t
      @drive.client_options.send_timeout_sec = t
    end

    attr_reader(:drive)

    def request_raw(method, url, data, extra_header, _auth)
      options = @drive.request_options.merge(header: extra_header)
      body = @drive.http(method, url, body: data, options: options)
      Response.new('200', body)
    end
  end
end
