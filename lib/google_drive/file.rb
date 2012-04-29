# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "stringio"

require "google_drive/util"
require "google_drive/acl"


module GoogleDrive
    
    # A file in Google Drive, including Google Docs document/spreadsheet/presentation.
    #
    # Use GoogleDrive::Session#files or GoogleDrive::Session#file_by_title to
    # get this object.
    class File

        include(Util)
        
        def initialize(session, entry) #:nodoc:
          @session = session
          @document_feed_entry = entry
          @document_feed_url = entry ? entry.css("link[rel='self']")[0]["href"] : nil
          @title = entry ? entry.css("title")[0].text : nil
          @acl = nil
        end
        
        # URL of feed used in document list feed API.
        attr_reader(:document_feed_url)
        
        # <entry> element of document list feed as Nokogiri::XML::Element.
        attr_reader(:document_feed_entry)
        
        # Title of the file.
        attr_reader(:title)
        
        # URL to view/edit the file in a Web browser.
        #
        # e.g. "https://docs.google.com/file/d/xxxx/edit"
        def human_url
          return self.document_feed_entry.css("link[rel='alternate']")[0]["href"]
        end
        
        # ACL feed URL of the file.
        def acl_feed_url
          orig_acl_feed_url = self.document_feed_entry.css(
              "gd|feedLink[rel='http://schemas.google.com/acl/2007#accessControlList']")[0]["href"]
          case orig_acl_feed_url
            when %r{^https?://docs.google.com/feeds/default/private/full/.*/acl(\?.*)?$}
              return orig_acl_feed_url
            when %r{^https?://docs.google.com/feeds/acl/private/full/([^\?]*)(\?.*)?$}
              # URL of old API version. Converts to v3 URL.
              return "https://docs.google.com/feeds/default/private/full/#{$1}/acl"
            else
              raise(GoogleDrive::Error,
                "ACL feed URL is in unknown format: #{orig_acl_feed_url}")
          end
        end

        # Content types you can specify in methods download_to_file, download_to_string,
        # download_to_io.
        def available_content_types
          return self.document_feed_entry.css("content").map(){ |c| c["type"] }
        end
        
        # Downloads the file to a local file.
        #
        # e.g.
        #   file.download_to_file("/path/to/hoge.txt")
        #   file.download_to_file("/path/to/hoge", :content_type => "text/plain")
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
        
        # Downloads the file and returns as a String.
        #
        # e.g.
        #   file.download_to_string()                               #=> "Hello world."
        #   file.download_to_string(:content_type => "text/plain")  #=> "Hello world."
        def download_to_string(params = {})
          sio = StringIO.new()
          download_to_io(sio, params)
          return sio.string
        end
        
        # Downloads the file and writes it to +io+.
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
              raise(GoogleDrive::Error,
                  ("Downloading with content type %p not supported for this file. " +
                   "Specify one of these to content_type: %p") %
                  [params[:content_type], self.available_content_types])
            else
              raise(GoogleDrive::Error,
                  ("Multiple content types are available for this file. " +
                   "Specify one of these to content_type: %p") %
                  [self.available_content_types])
            end
          end
          # TODO Use streaming if possible.
          body = @session.request(:get, url, :response_type => :raw, :auth => :writely)
          io.write(body)
        end
        
        # Updates the file with the content of the local file.
        #
        # e.g.
        #   file.update_from_file("/path/to/hoge.txt")
        def update_from_file(path, params = {})
          params = {:file_name => ::File.basename(path)}.merge(params)
          open(path, "rb") do |f|
            update_from_io(f, params)
          end
        end
        
        # Updates the file with +content+.
        #
        # e.g.
        #   file.update_from_string("Good bye, world.")
        def update_from_string(content, params = {})
          update_from_io(StringIO.new(content), params)
        end
        
        # Reads content from +io+ and updates the file with the content.
        def update_from_io(io, params = {})
          params = {:header => {"If-Match" => "*"}}.merge(params)
          initial_url = self.document_feed_entry.css(
              "link[rel='http://schemas.google.com/g/2005#resumable-edit-media']")[0]["href"]
          @document_feed_entry = @session.upload_raw(
              :put, initial_url, io, self.title, params)
        end
        
        # If +permanent+ is +false+, moves the file to the trash.
        # If +permanent+ is +true+, deletes the file permanently.
        def delete(permanent = false)
          @session.request(:delete,
            self.document_feed_url + (permanent ? "?delete=true" : ""),
            :auth => :writely, :header => {"If-Match" => "*"})
        end

        # Renames title of the file.
        def rename(title)
          
          doc = @session.request(:get, self.document_feed_url, :auth => :writely)
          edit_url = doc.css("link[rel='edit']").first["href"]
          xml = <<-"EOS"
            <atom:entry
                xmlns:atom="http://www.w3.org/2005/Atom"
                xmlns:docs="http://schemas.google.com/docs/2007">
              <atom:title>#{h(title)}</atom:title>
            </atom:entry>
          EOS
          
          @session.request(
              :put, edit_url, :data => xml, :auth => :writely,
              :header => {"Content-Type" => "application/atom+xml", "If-Match" => "*"})
          
        end
        
        alias title= rename
        
        # Returns GoogleDrive::Acl object for the file.
        #
        # With the object, you can see and modify people who can access the file.
        # Modifications take effect immediately.
        #
        # Set <tt>params[:reload]</tt> to true to force reloading the title.
        #
        # e.g.
        #   # Dumps people who have access:
        #   for entry in file.acl
        #     p [entry.scope_type, entry.scope, entry.role]
        #     # => e.g. ["user", "example1@gmail.com", "owner"]
        #   end
        #   
        #   # Shares the file with new people:
        #   # NOTE: This sends email to the new people.
        #   file.acl.push(
        #       {:scope_type => "user", :scope => "example2@gmail.com", :role => "reader"})
        #   file.acl.push(
        #       {:scope_type => "user", :scope => "example3@gmail.com", :role => "writer"})
        #   
        #   # Changes the role of a person:
        #   file.acl[1].role = "writer"
        #   
        #   # Deletes an ACL entry:
        #   file.acl.delete(file.acl[1])
        def acl(params = {})
          if !@acl || params[:reload]
            @acl = Acl.new(@session, self.acl_feed_url)
          end
          return @acl
        end

        def inspect
          return "\#<%p document_feed_url=%p>" % [self.class, self.document_feed_url]
        end
        
    end
    
end
