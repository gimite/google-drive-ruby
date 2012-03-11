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

        def as_utf8(str)
          if str.respond_to?(:force_encoding)
            str.force_encoding("UTF-8")
          else
            str
          end
        end

        def text_from_xpath(node,xpath)
          as_utf8(node.xpath(xpath).text)
        end

        def value_from_xpath(node,xpath,key)
          as_utf8(node.xpath(xpath).first[key])
        end
        
        def href_from_rel(node,rel,xp="./xmlns:link")
          as_utf8(node.xpath("#{xp}[@rel='#{rel}']").first["href"])
        end

        def batch_xml_open_section(url)
          <<-EOS
            <feed xmlns="http://www.w3.org/2005/Atom"
                  xmlns:batch="http://schemas.google.com/gdata/batch"
                  xmlns:gAcl="http://schemas.google.com/acl/2007"
                  xmlns:gs="http://schemas.google.com/spreadsheets/2006">
              <id>#{h(url)}</id>
          EOS
        end
        
        def batch_xml_close_section
          <<-EOS
            </feed>
          EOS
        end

    end
    
end
