# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "stringio"

require "google_spreadsheet/util"
require "google_spreadsheet/acl"


module GoogleSpreadsheet
    
    class File

        include(Util)
        
        def initialize(session, entry) #:nodoc:
          @session = session
          @document_feed_entry = entry
          @document_feed_url = entry ? entry.css("link[rel='self']")[0]["href"] : nil
          @title = entry ? entry.css("title")[0].text : nil
        end
        
        attr_reader(:document_feed_url, :document_feed_entry, :title)
        
        # URL to view/edit the file in a Web browser.
        #
        # e.g. "https://docs.google.com/file/d/xxxx/edit"
        def human_url
          return self.document_feed_entry.css("link[rel='alternate']")[0]["href"]
        end
        
        def available_content_types
          return self.document_feed_entry.css("content").map(){ |c| c["type"] }
        end
        
        def download_to_file(path, params = {})
          params = params.dup()
          if !params[:content_type]
            params[:content_type] = EXT_TO_CONTENT_TYPE[::File.extname(path).downcase]
            params[:content_type_is_hint] = true
          end
          open(path, "wb") do |f|
            download_to_io(f, params)
          end
        end
        
        def download_to_string(params = {})
          sio = StringIO.new()
          download_to_io(sio, params)
          return sio.string
        end
        
        def download_to_io(io, params = {})
          all_contents = self.document_feed_entry.css("content")
          if params[:content_type] && (!params[:content_type_is_hint] || all_contents.size > 1)
            contents = all_contents.select(){ |c| c["type"] == params[:content_type] }
          else
            contents = all_contents
          end
          if contents.size == 1
            url = contents[0]["src"]
          else
            if contents.empty?
              raise(GoogleSpreadsheet::Error,
                  ("Downloading with content type %p not supported for this file. " +
                   "Specify one of these to content_type: %p") %
                  [params[:content_type], self.available_content_types])
            else
              raise(GoogleSpreadsheet::Error,
                  ("Multiple content types are available for this file. " +
                   "Specify one of these to content_type: %p") %
                  [self.available_content_types])
            end
          end
          # TODO Use streaming if possible.
          body = @session.request(:get, url, :response_type => :raw, :auth => :writely)
          io.write(body)
        end
        
        def update_from_file(path, params = {})
          params = {:file_name => ::File.basename(path)}.merge(params)
          open(path, "rb") do |f|
            update_from_io(f, params)
          end
        end
        
        def update_from_string(body, params = {})
          update_from_io(StringIO.new(body), params)
        end
        
        def update_from_io(io, params = {})
          params = {:header => {"If-Match" => "*"}}.merge(params)
          initial_url = self.document_feed_entry.css(
              "link[rel='http://schemas.google.com/g/2005#resumable-edit-media']")[0]["href"]
          @document_feed_entry = @session.upload_raw(
              :put, initial_url, io, self.title, params)
        end
        
        def inspect
          return "\#<%p document_feed_url=%p>" % [self.class, self.document_feed_url]
        end
        
    end
    
end
