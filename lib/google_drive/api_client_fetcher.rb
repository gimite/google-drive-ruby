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
      # Make the timeout virtually infinite because some of the operations (e.g., uploading a large file)
      # can take very long.
      if @drive.request_options.respond_to?(:timeout_sec=)
        # google-api-client 0.9.x, 0.10.x
        @drive.request_options.timeout_sec      = 100_000_000
        @drive.request_options.open_timeout_sec = 100_000_000
      else
        # google-api-client 0.11.0 or later
        # see also: https://github.com/google/google-api-ruby-client/blob/0.11.0/MIGRATING.md#timeouts
        @drive.client_options.open_timeout_sec = 100_000_000
        @drive.client_options.read_timeout_sec = 100_000_000
        @drive.client_options.send_timeout_sec = 100_000_000
      end
    end

    attr_reader(:drive)

    def request_raw(method, url, data, extra_header, _auth)
      options = @drive.request_options.merge(header: extra_header)
      body = @drive.http(method, url, body: data, options: options)
      Response.new('200', body)
    end
  end
end
