# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_drive/util"
require "google_drive/error"
require "google_drive/spreadsheet"


module GoogleDrive

    # Use GoogleDrive::Session#collection_by_url to get GoogleDrive::Collection object.
    class Collection
        ROOT_URL = 'https://docs.google.com/feeds/default/private/full/folder%3Aroot'

        include(Util)

        def initialize(session, collection_feed_url = ROOT_URL) #:nodoc:
          @session = session
          @collection_feed_url = collection_feed_url
        end
        
        attr_reader(:collection_feed_url)
        
        # Adds the given GoogleDrive::File to the collection.
        def add(file)
          contents_url = concat_url(@collection_feed_url, "/contents")
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml"}
          xml = <<-"EOS"
            <entry xmlns="http://www.w3.org/2005/Atom">
              <id>#{h(file.document_feed_url)}</id>
            </entry>
          EOS
          @session.request(
              :post, contents_url, :data => xml, :header => header, :auth => :writely)
          return nil
        end

        # Returns the child resources in the collection (spreadsheets, documents, folders).
        #
        # ==== Parameters
        #
        # * +params+ is used to filter the returned resources as described at
        #   https://developers.google.com/google-apps/documents-list/#getting_a_list_of_documents_and_files
        #
        # * +type+ can be 'spreadsheet', 'document', 'folder' etc.
        #   If +type+ parameter is absent or nil the method will return 
        #   all types of resources including folders.
        #
        # ==== Examples:
        #
        #   # Gets all resources in collection, *including folders*
        #   contents 
        #
        #   # gets only resources with title "hoge"
        #   contents "title" => "hoge", "title-exact" => "true" 
        #
        #   contents {}, "spreadsheet"  # all speadsheets
        #   contents {}, "document"     # all text documents
        #   contents {}, "folder"       # all folders
        def contents(params = {}, type = nil)
          contents_url = concat_url(@collection_feed_url, "/contents")
          unless type.nil?
            contents_url << "/-/#{type}"
          end
          contents_url = concat_url contents_url, "?" + encode_query(params)
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml"}
          doc = @session.request(:get, contents_url, :header => header, :auth => :writely)
          return doc.css("feed > entry").map(){ |e| @session.entry_element_to_file(e) }
        end

        alias_method :files, :contents

        # Returns all the spreadsheets in the collection.
        def spreadsheets
          return self.files.select(){ |f| f.is_a?(Spreadsheet) }
        end
        
        # TODO Add other operations.
    end
    
end
