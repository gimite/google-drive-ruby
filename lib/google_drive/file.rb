# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "cgi"
require "forwardable"
require "stringio"

require "google_drive/util"
require "google_drive/acl"


module GoogleDrive
    
    # A file in Google Drive, including Google Docs document/spreadsheet/presentation.
    #
    # Use GoogleDrive::Session#files or GoogleDrive::Session#file_by_title to
    # get this object.
    #
    # In addition to the methods below, properties defined here are also available as attributes:
    # https://developers.google.com/drive/v2/reference/files#resource
    #
    # e.g.,
    #   file.mime_type  # ==> "text/plain"
    class File

        include(Util)
        extend(Forwardable)
        
        def initialize(session, api_file) #:nodoc:
          @session = session
          @api_file = api_file
          @acl = nil
          delegate_api_methods(self, @api_file, ["title"])
        end

        # Wrapped Google::APIClient::Schema::Drive::V2::File object.
        attr_reader(:api_file)

        # Reloads file metadata such as title and acl.
        def reload_metadata()
          api_result = @session.execute!(
            :api_method => @session.drive.files.get,
            :parameters => { "fileId" => self.id })
          @api_file = api_result.data
          if @acl
            @acl = Acl.new(@session, self)
          end
        end

        # Returns resource_type + ":" + id.
        def resource_id
          return "%s:%s" % [self.resource_type, self.id]
        end

        # URL of feed used in the deprecated document list feed API.
        def document_feed_url
          return "https://docs.google.com/feeds/default/private/full/" + CGI.escape(self.resource_id)
        end

        # Deprecated ACL feed URL of the file.
        def acl_feed_url
          return self.document_feed_url + "/acl"
        end

        # The type of resourse. e.g. "document", "spreadsheet", "folder"
        def resource_type
          return self.mime_type.slice(/^application\/vnd.google-apps.(.+)$/, 1) || "file"
        end

        # Title of the file.
        def title(params = {})
          reload_metadata() if params[:reload]
          return self.api_file.title
        end
        
        # URL to view/edit the file in a Web browser.
        #
        # e.g. "https://docs.google.com/file/d/xxxx/edit"
        def human_url
          return self.alternate_link
        end
        
        # Content types you can specify in methods download_to_file, download_to_string,
        # download_to_io .
        #
        # This returns zero or one file type. You may be able to download the file in other formats using
        # export_as_file, export_as_string, or export_to_io. Use export_links method to get available formats
        # in these methods.
        def available_content_types
          if self.api_file.download_url
            return [self.api_file.mime_type]
          else
            return []
          end
        end
        
        # Downloads the file to a local file. e.g.
        #   file.download_to_file("/path/to/hoge.txt")
        #
        # To export the file in other formats, use export_as_file.
        def download_to_file(path, params = {})
          open(path, "wb") do |f|
            download_to_io(f, params)
          end
        end
        
        # Downloads the file and returns as a String.
        #
        # To export the file in other formats, use export_as_string.
        def download_to_string(params = {})
          sio = StringIO.new()
          download_to_io(sio, params)
          return sio.string
        end
        
        # Downloads the file and writes it to +io+.
        #
        # To export the file in other formats, use export_to_io.
        def download_to_io(io, params = {})
          if !self.api_file.download_url
            raise(GoogleDrive::Error, "Downloading is not supported for this file.")
          end
          # TODO Use streaming if possible.
          api_result = @session.execute!(:uri => self.api_file.download_url)
          io.write(api_result.body)
        end

        # Export the file to +path+ in content type +format+.
        # If +format+ is nil, it is guessed from the file name.
        #
        # e.g.,
        #   spreadsheet.export_as_file("/path/to/hoge.csv")
        #   spreadsheet.export_as_file("/path/to/hoge", "text/csv")
        #
        # If you want to download the file in the original format, use download_to_file instead.
        def export_as_file(path, format = nil)
          if !format
            format = EXT_TO_CONTENT_TYPE[::File.extname(path).downcase]
            if !format
              raise(ArgumentError,
                  ("Cannot guess format from the file name: %s\n" +
                   "Specify format argument explicitly.") %
                  path)
            end
          end
          open(path, "wb") do |f|
            export_to_io(f, format)
          end
        end
        
        # Export the file as String in content type +format+.
        #
        # e.g.,
        #   spreadsheet.export_as_string("text/csv")
        #
        # If you want to download the file in the original format, use download_to_string instead.
        def export_as_string(format)
          sio = StringIO.new()
          export_to_io(sio, format)
          return sio.string
        end

        # Export the file to +io+ in content type +format+.
        #
        # If you want to download the file in the original format, use download_to_io instead.
        def export_to_io(io, format)
          mime_type = EXT_TO_CONTENT_TYPE["." + format] || format
          if !self.export_links
            raise(
                GoogleDrive::Error,
                "This file doesn't support exporting. You may still download the file in the " +
                "original format using download_to_file, download_to_string or download_to_io.")
          end
          export_url = self.export_links[mime_type]
          if !export_url
            raise(
                GoogleDrive::Error,
                "This file doesn't support export with mime type %p. Supported mime types: %p" %
                    [mime_type, self.export_links.to_hash().keys])
          end
          # TODO Use streaming if possible.
          api_result = @session.execute!(:uri => export_url)
          io.write(api_result.body)
        end
        
        # Updates the file with +content+.
        #
        # e.g.
        #   file.update_from_string("Good bye, world.")
        def update_from_string(content, params = {})
          media = new_upload_io(StringIO.new(content), params)
          return update_from_media(media, params)
        end
        
        # Updates the file with the content of the local file.
        #
        # e.g.
        #   file.update_from_file("/path/to/hoge.txt")
        def update_from_file(path, params = {})
          file_name = ::File.basename(path)
          params = {:file_name => file_name}.merge(params)
          media = new_upload_io(path, params)
          return update_from_media(media, params)
        end

        # Reads content from +io+ and updates the file with the content.
        def update_from_io(io, params = {})
          media = new_upload_io(io, params)
          return update_from_media(media, params)
        end

        # Reads content from +media+ and updates the file with the content.
        def update_from_media(media, params = {})
          api_result = @session.execute!(
              :api_method => @session.drive.files.update,
              :media => media,
              :parameters => {
                "fileId" => self.id,
                "uploadType" => "media",
              })
          return @session.wrap_api_file(api_result.data)
        end

        # If +permanent+ is +false+, moves the file to the trash.
        # If +permanent+ is +true+, deletes the file permanently.
        def delete(permanent = false)
          if permanent
            @session.execute!(
                :api_method => @session.drive.files.delete,
                :parameters => {"fileId" => self.id})
          else
            @session.execute!(
                :api_method => @session.drive.files.trash,
                :parameters => {"fileId" => self.id})
          end
          return nil
        end

        # Renames title of the file.
        def rename(title)
          api_result = @session.execute!(
              :api_method => @session.drive.files.patch,
              :body_object => {"title" => title},
              :parameters => {"fileId" => self.id})
          @api_file = api_result.data
        end
        
        alias title= rename

        # Creates copy of this file with the given title.
        def copy(title)
          copied_file = @session.drive.files.copy.request_schema.new({
              "title" => title,
          })
          api_result = @session.execute!(
              :api_method => @session.drive.files.copy,
              :body_object => copied_file,
              :parameters => {"fileId" => self.id})
          return @session.wrap_api_file(api_result.data)
        end

        alias duplicate copy
        
        # Returns GoogleDrive::Acl object for the file.
        #
        # With the object, you can see and modify people who can access the file.
        # Modifications take effect immediately.
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
        #       {:type => "user", :value => "example2@gmail.com", :role => "reader"})
        #   file.acl.push(
        #       {:type => "user", :value => "example3@gmail.com", :role => "writer"})
        #   
        #   # Changes the role of a person:
        #   file.acl[1].role = "writer"
        #   
        #   # Deletes an ACL entry:
        #   file.acl.delete(file.acl[1])
        def acl(params = {})
          if !@acl || params[:reload]
            @acl = Acl.new(@session, self)
          end
          return @acl
        end

        def inspect
          return "\#<%p id=%p title=%p>" % [self.class, self.id, self.title]
        end
        
    end
    
end
