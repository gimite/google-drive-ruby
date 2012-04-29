# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_drive/util"
require "google_drive/error"
require "google_drive/record"


module GoogleDrive

    # DEPRECATED: Table and Record feeds are deprecated and they will not be available after
    # March 2012.
    #
    # Use GoogleDrive::Worksheet#add_table to create table.
    # Use GoogleDrive::Worksheet#tables to get GoogleDrive::Table objects.
    class Table

        include(Util)

        def initialize(session, entry) #:nodoc:
          @columns = {}
          @worksheet_title = entry.css("gs|worksheet")[0]["name"]
          @records_url = entry.css("content")[0]["src"]
          @edit_url = entry.css("link[rel='edit']")[0]["href"]
          @session = session
        end

        # Title of the worksheet the table belongs to.
        attr_reader(:worksheet_title)

        # Adds a record.
        def add_record(values)
          fields = ""
          values.each() do |name, value|
            fields += "<gs:field name='#{h(name)}'>#{h(value)}</gs:field>"
          end
          xml =<<-EOS
            <entry
                xmlns="http://www.w3.org/2005/Atom"
                xmlns:gs="http://schemas.google.com/spreadsheets/2006">
              #{fields}
            </entry>
          EOS
          @session.request(:post, @records_url, :data => xml)
        end

        # Returns records in the table.
        def records
          doc = @session.request(:get, @records_url)
          return doc.css("entry").map(){ |e| Record.new(@session, e) }
        end

        # Deletes this table. Deletion takes effect right away without calling save().
        def delete
          @session.request(:delete, @edit_url, :header => {"If-Match" => "*"})
        end

    end
    
end
