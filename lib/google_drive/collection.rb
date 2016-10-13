# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require 'google_drive/util'
require 'google_drive/error'
require 'google_drive/spreadsheet'

module GoogleDrive
  # Use GoogleDrive::Session#root_collection, GoogleDrive::Collection#subcollections,
  # or GoogleDrive::Session#collection_by_url to get GoogleDrive::Collection object.
  class Collection < GoogleDrive::File
    include(Util)

    alias_method :collection_feed_url, :document_feed_url

    # Adds the given GoogleDrive::File to the collection.
    def add(file)
      @session.drive.update_file(file.id, add_parents: self.id, fields: '')
      nil
    end

    # Removes the given GoogleDrive::File from the collection.
    def remove(file)
      @session.drive.update_file(file.id, remove_parents: self.id, fields: '')
    end

    # Creates a sub-collection with given title. Returns GoogleDrive::Collection object.
    def create_subcollection(title)
      file_metadata = {
        name: title,
        mime_type: 'application/vnd.google-apps.folder',
        parents: [self.id],
      }
      file = @session.drive.create_file(file_metadata, fields: '*')
      @session.wrap_api_file(file)
    end

    # Returns true if this is a root collection
    def root?
      !api_file.parents || api_file.parents.empty?
    end

    # Returns all the files (including spreadsheets, documents, subcollections) in the collection.
    # You can specify parameters documented at
    # https://developers.google.com/drive/v3/web/search-parameters
    #
    # e.g.
    #
    #   # Gets all the files in the collection, including subcollections.
    #   collection.files
    #
    #   # Gets only files with title "hoge".
    #   collection.files(q: "name = 'hoge'")
    #
    #   # Same as above with a placeholder.
    #   collection.files(q: ["name = ?", "hoge"])
    #
    # By default, it returns the first 100 files. See document of GoogleDrive::Session#files method
    # for how to get all files.
    def files(params = {}, &block)
      files_with_type(nil, params, &block)
    end

    # Same as Session#upload_from_file. It uploads file to current collection
    def upload_from_file(path, title = nil, params = {})
      params = {parents: [self.id]}.merge(params)
      @session.upload_from_file(path, title, params)
    end

    # Same as Session#upload_from_io. It uploads file to current collection
    def upload_from_io(io, title = 'Untitled', params = {})
      params = {parents: [self.id]}.merge(params)
      @session.upload_from_io(io, title, params)
    end

    # Same as Session#upload_from_string. It uploads file to current collection
    def upload_from_string(content, title = 'Untitled', params = {})
      params = {parents: [self.id]}.merge(params)
      @session.upload_from_string(content, title, params)
    end

    alias_method :contents, :files

    # Returns all the spreadsheets in the collection.
    #
    # By default, it returns the first 100 spreadsheets. See document of GoogleDrive::Session#files method
    # for how to get all spreadsheets.
    def spreadsheets(params = {}, &block)
      files_with_type('application/vnd.google-apps.spreadsheet', params, &block)
    end

    # Returns all the Google Docs documents in the collection.
    #
    # By default, it returns the first 100 documents. See document of GoogleDrive::Session#files method
    # for how to get all documents.
    def documents(params = {}, &block)
      files_with_type('application/vnd.google-apps.document', params, &block)
    end

    # Returns all its subcollections.
    #
    # By default, it returns the first 100 subcollections. See document of GoogleDrive::Session#files method
    # for how to get all subcollections.
    def subcollections(params = {}, &block)
      files_with_type('application/vnd.google-apps.folder', params, &block)
    end

    # Returns a file (can be a spreadsheet, document, subcollection or other files) in the
    # collection which exactly matches +title+ as GoogleDrive::File.
    # Returns nil if not found. If multiple collections with the +title+ are found, returns
    # one of them.
    #
    # If given an Array, does a recursive subcollection traversal.
    def file_by_title(title)
      file_by_title_with_type(title, nil)
    end

    # Returns its subcollection whose title exactly matches +title+ as GoogleDrive::Collection.
    # Returns nil if not found. If multiple collections with the +title+ are found, returns
    # one of them.
    #
    # If given an Array, does a recursive subcollection traversal.
    def subcollection_by_title(title)
      file_by_title_with_type(title, 'application/vnd.google-apps.folder')
    end

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

    private

    def files_with_type(type, params = {}, &block)
      params = convert_params(params)
      query  = construct_and_query([
        ['? in parents', id],
        type ? ['mimeType = ?', type] : nil,
        params[:q]
      ])
      params = params.merge(q: query)
      # This is faster than calling children.list and then files.get for each file.
      @session.files(params, &block)
    end
  end
end
