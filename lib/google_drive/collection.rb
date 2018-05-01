# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require 'google_drive/util'
require 'google_drive/error'
require 'google_drive/spreadsheet'

module GoogleDrive
  # Represents a folder in Google Drive.
  #
  # Use GoogleDrive::Session#root_collection,
  # GoogleDrive::Collection#subcollections,
  # or GoogleDrive::Session#collection_by_url to get GoogleDrive::Collection
  # object.
  class Collection < GoogleDrive::File
    include(Util)

    alias collection_feed_url document_feed_url

    # Adds the given GoogleDrive::File to the folder.
    def add(file)
      @session.drive.update_file(
        file.id, add_parents: id, fields: '', supports_team_drives: true
      )
      nil
    end

    # Removes the given GoogleDrive::File from the folder.
    def remove(file)
      @session.drive.update_file(
        file.id, remove_parents: id, fields: '', supports_team_drives: true
      )
    end

    # Creates a sub-folder with given title in this folder.
    # Returns GoogleDrive::Collection object.
    def create_subcollection(title, file_properties = {})
      create_file(title, file_properties.merge(mime_type: 'application/vnd.google-apps.folder'))
    end

    alias create_subfolder create_subcollection

    # Creates a spreadsheet with given title in this folder.
    # Returns GoogleDrive::Spreadsheet object.
    def create_spreadsheet(title, file_properties = {})
      create_file(title, file_properties.merge(mime_type: 'application/vnd.google-apps.spreadsheet'))
    end

    # Creates a file with given title and properties in this folder.
    # Returns objects with the following types:
    # GoogleDrive::Spreadsheet, GoogleDrive::File, GoogleDrive::Collection
    #
    # You can pass a MIME Type using the file_properties-function parameter,
    # for example: create_file('Document Title', mime_type: 'application/vnd.google-apps.document')
    #
    # A list of available Drive MIME Types can be found here:
    # https://developers.google.com/drive/v3/web/mime-types
    def create_file(title, file_properties = {})
      file_metadata = {
        name: title,
        parents: [id]
      }.merge(file_properties)

      file = @session.drive.create_file(
        file_metadata, fields: '*', supports_team_drives: true
      )

      @session.wrap_api_file(file)
    end

    # Returns true if this is a root folder.
    def root?
      !api_file.parents || api_file.parents.empty?
    end

    # Returns all the files (including spreadsheets, documents, subfolders) in
    # the folder. You can specify parameters documented at
    # https://developers.google.com/drive/v3/web/search-parameters
    #
    # e.g.
    #
    #   # Gets all the files in the folder, including subfolders.
    #   collection.files
    #
    #   # Gets only files with title "hoge".
    #   collection.files(q: "name = 'hoge'")
    #
    #   # Same as above with a placeholder.
    #   collection.files(q: ["name = ?", "hoge"])
    #
    # By default, it returns the first 100 files. See document of
    # GoogleDrive::Session#files method for how to get all files.
    def files(params = {}, &block)
      files_with_type(nil, params, &block)
    end

    # Uploads a file to this folder. See Session#upload_from_file for details.
    def upload_from_file(path, title = nil, params = {})
      params = { parents: [id] }.merge(params)
      @session.upload_from_file(path, title, params)
    end

    # Uploads a file to this folder. See Session#upload_from_io for details.
    def upload_from_io(io, title = 'Untitled', params = {})
      params = { parents: [id] }.merge(params)
      @session.upload_from_io(io, title, params)
    end

    # Uploads a file to this folder. See Session#upload_from_string for details.
    def upload_from_string(content, title = 'Untitled', params = {})
      params = { parents: [id] }.merge(params)
      @session.upload_from_string(content, title, params)
    end

    alias contents files

    # Returns all the spreadsheets in the folder.
    #
    # By default, it returns the first 100 spreadsheets. See document of
    # GoogleDrive::Session#files method for how to get all spreadsheets.
    def spreadsheets(params = {}, &block)
      files_with_type('application/vnd.google-apps.spreadsheet', params, &block)
    end

    # Returns all the Google Docs documents in the folder.
    #
    # By default, it returns the first 100 documents. See document of
    # GoogleDrive::Session#files method for how to get all documents.
    def documents(params = {}, &block)
      files_with_type('application/vnd.google-apps.document', params, &block)
    end

    # Returns all its subfolders.
    #
    # By default, it returns the first 100 subfolders. See document of
    # GoogleDrive::Session#files method for how to get all subfolders.
    def subcollections(params = {}, &block)
      files_with_type('application/vnd.google-apps.folder', params, &block)
    end

    alias subfolders subcollections

    # Returns a file (can be a spreadsheet, document, subfolder or other files)
    # in the folder which exactly matches +title+ as GoogleDrive::File.
    # Returns nil if not found. If multiple folders with the +title+ are found,
    # returns one of them.
    #
    # If given an Array, does a recursive subfolder traversal.
    def file_by_title(title)
      file_by_title_with_type(title, nil)
    end

    alias file_by_name file_by_title

    # Returns its subfolder whose title exactly matches +title+ as
    # GoogleDrive::Collection.
    # Returns nil if not found. If multiple folders with the +title+ are found,
    # returns one of them.
    #
    # If given an Array, does a recursive subfolder traversal.
    def subcollection_by_title(title)
      file_by_title_with_type(title, 'application/vnd.google-apps.folder')
    end

    alias subfolder_by_name subcollection_by_title

    # Returns URL of the deprecated contents feed.
    def contents_url
      document_feed_url + '/contents'
    end

    protected

    def file_by_title_with_type(title, type)
      if title.is_a?(Array)
        rel_path = title
        if rel_path.empty?
          return self
        else
          parent = subcollection_by_title(rel_path[0...-1])
          return parent && parent.file_by_title_with_type(rel_path[-1], type)
        end
      else
        files_with_type(type, q: ['name = ?', title], page_size: 1)[0]
      end
    end

    alias file_by_name_with_type file_by_title_with_type

    private

    def files_with_type(type, params = {}, &block)
      params = convert_params(params)
      query  = construct_and_query([
                                     ['? in parents', id],
                                     type ? ['mimeType = ?', type] : nil,
                                     params[:q]
                                   ])
      params = params.merge(q: query)
      # This is faster than calling children.list and then files.get for each
      # file.
      @session.files(params, &block)
    end
  end

  Folder = Collection
end
