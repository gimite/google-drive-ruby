# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_spreadsheet/util"
require "google_spreadsheet/error"
require "google_spreadsheet/spreadsheet"


module GoogleSpreadsheet

    # Use GoogleSpreadsheet::Session#collection_by_url to get GoogleSpreadsheet::Collection object.
    class Collection

        include(Util)
        
        def initialize(session, collection_feed_url) #:nodoc:
          @session = session
          @collection_feed_url = collection_feed_url
        end
        
        attr_reader(:collection_feed_url)
        
        # Adds the given GoogleSpreadsheet::File to the collection.
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

        # Returns all the files in the collection.
        def files
          contents_url = concat_url(@collection_feed_url, "/contents")
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml"}
          doc = @session.request(:get, contents_url, :header => header, :auth => :writely)
          return doc.css("feed > entry").map(){ |e| @session.entry_element_to_file(e) }
        end
        
        # Returns all the spreadsheets in the collection.
        def spreadsheets
          return self.files.select(){ |f| f.is_a?(Spreadsheet) }
        end
        
        # TODO Add other operations.

    end
    
end
