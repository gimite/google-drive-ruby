# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "cgi"

require "google/api_client"


module GoogleDrive
    
    module Util #:nodoc:

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

        def h(str)
          # Should also escape "\n" to keep it in cell contents.
          return CGI.escapeHTML(str.to_s()).gsub(/\n/, '&#x0a;')
        end
        
        def construct_query(arg)

          case arg

            when String
              return arg

            when Array
              if arg[0].scan(/\?/).size != arg.size - 1
                raise(
                    ArgumentError,
                    "The number of placeholders doesn't match the number of arguments: %p" % [arg])
              end
              i = 1
              return arg[0].gsub(/\?/) do
                v = arg[i]
                i += 1
                case v
                  when String
                    "'%s'" % v.gsub(/['\\]/){ "\\" + $& }
                  when Time
                    "'%s'" % v.iso8601
                  when TrueClass
                    "true"
                  when FalseClass
                    "false"
                  else
                    raise(ArgumentError, "Expected String, Time, true or false, but got %p" % [v])
                end
              end

            else
              raise(ArgumentError, "Expected String or Array, but got %p" % [arg])

          end

        end

        def construct_and_query(args)
          return args.select(){ |a| a }.map(){ |a| "(%s)" % construct_query(a) }.join(" and ")
        end

        def convert_params(params)
          str_params = {}
          for k, v in params
            str_params[k.to_s()] = v
          end
          old_terms = []
          new_params = {}
          for k, v in str_params
            case k
              when "q"
                new_params["q"] = construct_query(v)
              # Parameters in the old API.
              when "title"
                if str_params["title-exact"].to_s() == "true"
                  old_terms.push(["title = ?", v])
                else
                  old_terms.push(["title contains ?", v])
                end
              when "title-exact"
                # Skips it. It is handled above.
              when "opened-min"
                old_terms.push(["lastViewedByMeDate >= ?", v])
              when "opened-max"
                old_terms.push(["lastViewedByMeDate <= ?", v])
              when "edited-min"
                old_terms.push(["modifiedDate >= ?", v])
              when "edited-max"
                old_terms.push(["modifiedDate <= ?", v])
              when "owner"
                old_terms.push(["? in owners", v])
              when "writer"
                old_terms.push(["? in writers", v])
              when "reader"
                old_terms.push(["? in readers", v])
              when "showfolders"
                if v.to_s() == "false"
                  old_terms.push("mimeType != 'application/vnd.google-apps.folder'")
                end
              when "showdeleted"
                if v.to_s() == "false"
                  old_terms.push("trashed = false")
                end
              when "ocr", "targetLanguage", "sourceLanguage"
                raise(ArgumentError, "'%s' parameter is no longer supported." % k)
              else
                new_params[k] = v
            end
          end
          if !old_terms.empty?
            if new_params.has_key?("q")
              raise(ArgumentError, "Cannot specify both 'q' parameter and old query parameters.")
            else
              new_params["q"] = construct_and_query(old_terms)
            end
          end
          return new_params
        end

        def singleton_class(obj)
          class << obj
            return self
          end
        end

        def delegate_api_methods(obj, api_obj, exceptions = [])
          sc = singleton_class(obj)
          names = api_obj.class.keys.keys - exceptions
          names.each() do |name|
            sc.__send__(:define_method, name) do
              api_obj.__send__(name)
            end
          end
        end

        def new_upload_io(path_or_io, params)
          content_type =
              params[:content_type] ||
              (params[:file_name] ? EXT_TO_CONTENT_TYPE[::File.extname(params[:file_name]).downcase] : nil) ||
              "application/octet-stream"
          return Google::APIClient::UploadIO.new(path_or_io, content_type)
        end
        
    end
    
end
