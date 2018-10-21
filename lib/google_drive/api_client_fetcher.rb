# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require 'net/https'
require 'uri'
require 'google/apis/drive_v3'
require 'google/apis/sheets_v4'
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

    def initialize(authorization, client_options, request_options)
      @drive = Google::Apis::DriveV3::DriveService.new
      @sheets = Google::Apis::SheetsV4::SheetsService.new

      [@drive, @sheets].each do |service|
        service.authorization = authorization

        # Make the timeout virtually infinite because some of the operations
        # (e.g., uploading a large file) can take very long.
        # This value is the maximal allowed timeout in seconds on JRuby.
        t = (2**31 - 1) / 1000
        service.client_options.open_timeout_sec = t
        service.client_options.read_timeout_sec = t
        service.client_options.send_timeout_sec = t

        if client_options
          service.client_options.members.each do |name|
            if !client_options[name].nil?
              service.client_options[name] = client_options[name]
            end
          end
        end

        if request_options
          service.request_options = service.request_options.merge(request_options)
        end
      end
    end

    attr_reader(:drive)
    attr_reader(:sheets)

    def request_raw(method, url, data, extra_header, _auth)
      options = @drive.request_options.merge(header: extra_header)
      body = @drive.http(method, url, body: data, options: options)
      Response.new('200', body)
    end
  end
end
