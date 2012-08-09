# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "cgi"


module GoogleDrive
    
    module Util #:nodoc:

        # The beginning of Doc List API URL that is used in all requests (version 3).
        DOCS_BASE_URL = "https://docs.google.com/feeds/default/private/full"
        
        EXT_TO_CONTENT_TYPE = {
            ".csv" =>"text/csv",
            ".tsv" =>"text/tab-separated-values",
            ".tab" =>"text/tab-separated-values",
            ".doc" =>"application/msword",
            ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            ".ods" =>"application/x-vnd.oasis.opendocument.spreadsheet",
            ".odt" =>"application/vnd.oasis.opendocument.text",
            ".rtf" =>"application/rtf",
            ".sxw" =>"application/vnd.sun.xml.writer",
            ".txt" =>"text/plain",
            ".xls" =>"application/vnd.ms-excel",
            ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            ".pdf" =>"application/pdf",
            ".png" =>"image/png",
            ".ppt" =>"application/vnd.ms-powerpoint",
            ".pps" =>"application/vnd.ms-powerpoint",
            ".htm" =>"text/html",
            ".html" =>"text/html",
            ".zip" =>"application/zip",
            ".swf" =>"application/x-shockwave-flash",
        }
        
      module_function
        
        def encode_query(params)
          return params.map(){ |k, v| CGI.escape(k.to_s()) + "=" + CGI.escape(v.to_s()) }.join("&")
        end
        
        def concat_url(url, piece)
          (url_base, url_query) = url.split(/\?/, 2)
          (piece_base, piece_query) = piece.split(/\?/, 2)
          result_query = [url_query, piece_query].select(){ |s| s && !s.empty? }.join("&")
          return (url_base || "") +
              (piece_base || "") +
              (result_query.empty? ? "" : "?#{result_query}")
        end

        # Returns a URL with added version parameter ("?v=3") if needed.
        def to_v3_url(url)
          if url =~ %r{docs.google.com/feeds/default/private/} && !(url =~ /[?&]v=3/)
            return concat_url(url, "?v=3")
          else
            return url
          end
        end

        def h(str)
          # Should also escape "\n" to keep it in cell contents.
          return CGI.escapeHTML(str.to_s()).gsub(/\n/, '&#x0a;')
        end
        
    end
    
end
