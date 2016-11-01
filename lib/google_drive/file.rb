# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require 'cgi'
require 'forwardable'
require 'stringio'

require 'google_drive/util'
require 'google_drive/acl'
require 'api/spreadsheets'

module GoogleDrive
  # A file in Google Drive, including Google Docs document/spreadsheet/presentation.
  #
  # Use GoogleDrive::Session#files or GoogleDrive::Session#file_by_title to
  # get this object.
  #
  # In addition to the methods below, properties defined here are also available as attributes:
  # https://developers.google.com/drive/v3/reference/files#resource
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
      delegate_api_methods(self, @api_file, [:title])
      auth_data = @session.drive.request_options.authorization
      access_token = auth_data.access_token # client_id
      client_id = auth_data.client_id
      @sheet_api = SpreadsheetsApi.new(access_token, client_id)
    end

    # Wrapped Google::APIClient::Schema::Drive::V3::File object.
    attr_reader(:api_file)

    # Reloads file metadata such as title and acl.
    def reload_metadata
      @api_file = @session.drive.get_file(id, fields: '*')
      @acl = Acl.new(@session, self) if @acl
    end

    # Returns resource_type + ":" + id.
    def resource_id
      '%s:%s' % [resource_type, id]
    end

    # URL of feed used in the deprecated document list feed API.
    def document_feed_url
      'https://docs.google.com/feeds/default/private/full/' + CGI.escape(resource_id)
    end

    # Deprecated ACL feed URL of the file.
    def acl_feed_url
      document_feed_url + '/acl'
    end

    # The type of resourse. e.g. "document", "spreadsheet", "folder"
    def resource_type
      mime_type.slice(/^application\/vnd.google-apps.(.+)$/, 1) || 'file'
    end

    # Title of the file.
    def title(params = {})
      reload_metadata if params[:reload]
      api_file.name
    end

    # URL to view/edit the file in a Web browser.
    #
    # e.g. "https://docs.google.com/file/d/xxxx/edit"
    def human_url
      api_file.web_view_link
    end

    # Content types you can specify in methods download_to_file, download_to_string,
    # download_to_io .
    #
    # This returns zero or one file type. You may be able to download the file in other formats using
    # export_as_file, export_as_string, or export_to_io.
    def available_content_types
      api_file.web_content_link ? [api_file.mime_type] : []
    end

    # Downloads the file to a local file. e.g.
    #   file.download_to_file("/path/to/hoge.txt")
    #
    # To export the file in other formats, use export_as_file.
    def download_to_file(path, params = {})
      @session.drive.get_file(id, {download_dest: path}.merge(params))
    end

    # Downloads the file and returns as a String.
    #
    # To export the file in other formats, use export_as_string.
    def download_to_string(params = {})
      sio = StringIO.new
      download_to_io(sio, params)
      sio.string
    end

    # Downloads the file and writes it to +io+.
    #
    # To export the file in other formats, use export_to_io.
    def download_to_io(io, params = {})
      @session.drive.get_file(id, {download_dest: io}.merge(params))
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
      unless format
        format = EXT_TO_CONTENT_TYPE[::File.extname(path).downcase]
        unless format
          fail(ArgumentError,
               ("Cannot guess format from the file name: %s\n" \
                'Specify format argument explicitly.') %
               path)
        end
      end
      export_to_dest(path, format)
    end

    # Export the file as String in content type +format+.
    #
    # e.g.,
    #   spreadsheet.export_as_string("text/csv")
    #
    # If you want to download the file in the original format, use download_to_string instead.
    def export_as_string(format)
      sio = StringIO.new
      export_to_dest(sio, format)
      sio.string
    end

    # Export the file to +io+ in content type +format+.
    #
    # If you want to download the file in the original format, use download_to_io instead.
    def export_to_io(io, format)
      export_to_dest(io, format)
    end

    # Updates the file with +content+.
    #
    # e.g.
    #   file.update_from_string("Good bye, world.")
    def update_from_string(content, params = {})
      update_from_io(StringIO.new(content), params)
    end

    # Updates the file with the content of the local file.
    #
    # e.g.
    #   file.update_from_file("/path/to/hoge.txt")
    def update_from_file(path, params = {})
      # Somehow it doesn't work if I specify the file name directly as upload_source.
      open(path, 'rb') do |f|
        update_from_io(f, params)
      end
      nil
    end

    # Reads content from +io+ and updates the file with the content.
    def update_from_io(io, params = {})
      params = { upload_source: io }.merge(params)
      @session.drive.update_file(id, nil, params)
      nil
    end

    # If +permanent+ is +false+, moves the file to the trash.
    # If +permanent+ is +true+, deletes the file permanently.
    def delete(permanent = false)
      if permanent
        @session.drive.delete_file(id)
      else
        @session.drive.update_file(id, { trashed: true }, {})
      end
      nil
    end

    # Renames title of the file.
    def rename(title)
      @session.drive.update_file(id, { name: title }, {})
      nil
    end

    alias_method :title=, :rename

    # Creates copy of this file with the given title.
    def copy(title)
      api_file = @session.drive.copy_file(id, { name: title }, {})
      @session.wrap_api_file(api_file)
    end

    alias_method :duplicate, :copy

    # Returns GoogleDrive::Acl object for the file.
    #
    # With the object, you can see and modify people who can access the file.
    # Modifications take effect immediately.
    #
    # e.g.
    #   # Dumps people who have access:
    #   for entry in file.acl
    #     p [entry.type, entry.email_address, entry.role]
    #     # => e.g. ["user", "example1@gmail.com", "owner"]
    #   end
    #
    #   # Shares the file with new people:
    #   # NOTE: This sends email to the new people.
    #   file.acl.push(
    #       {type: "user", email_address: "example2@gmail.com", role: "reader"})
    #   file.acl.push(
    #       {type: "user", email_address: "example3@gmail.com", role: "writer"})
    #
    #   # Changes the role of a person:
    #   file.acl[1].role = "writer"
    #
    #   # Deletes an ACL entry:
    #   file.acl.delete(file.acl[1])
    def acl(params = {})
      @acl = Acl.new(@session, self) if !@acl || params[:reload]
      @acl
    end

    def inspect
      "\#<%p id=%p title=%p>" % [self.class, id, title]
    end

    private

    def export_to_dest(dest, format)
      mime_type = EXT_TO_CONTENT_TYPE['.' + format] || format
      @session.drive.export_file(id, mime_type, download_dest: dest)
      nil
    end
  end
end
