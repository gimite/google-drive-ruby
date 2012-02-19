# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "cgi"


module GoogleSpreadsheet

    module Util #:nodoc:

      module_function

        def encode_query(params)
          return params.map(){ |k, v| CGI.escape(k) + "=" + CGI.escape(v) }.join("&")
        end
        
        def concat_url(url, piece)
          (url_base, url_query) = url.split(/\?/, 2)
          (piece_base, piece_query) = piece.split(/\?/, 2)
          result_query = [url_query, piece_query].select(){ |s| s && !s.empty? }.join("&")
          return url_base + piece_base + (result_query.empty? ? "" : "?#{result_query}")
        end

        def h(str)
          return CGI.escapeHTML(str.to_s())
        end

    end
    
end
