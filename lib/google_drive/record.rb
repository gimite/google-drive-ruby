# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_drive/util"
require "google_drive/error"


module GoogleDrive

    # DEPRECATED: Table and Record feeds are deprecated and they will not be available after
    # March 2012.
    #
    # Use GoogleDrive::Table#records to get GoogleDrive::Record objects.
    class Record < Hash
        include(Util)

        def initialize(session, entry) #:nodoc:
          @session = session
          entry.css("gs|field").each() do |field|
            self[field["name"]] = field.inner_text
          end
        end

        def inspect #:nodoc:
          content = self.map(){ |k, v| "%p => %p" % [k, v] }.join(", ")
          return "\#<%p:{%s}>" % [self.class, content]
        end

    end

end
