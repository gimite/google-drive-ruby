# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "cgi"

require "google_drive/error"


module GoogleDrive

    # Raised when an HTTP request has returned an unexpected response code.
    class ResponseCodeError < GoogleDrive::Error

        def initialize(code, body, method, url) #:nodoc:#
          @code = code
          @body = body
          super("Response code %s for %s %s: %s" % [code, method, url, CGI.unescapeHTML(body)])
        end

        attr_reader(:code, :body)

    end
    
end
