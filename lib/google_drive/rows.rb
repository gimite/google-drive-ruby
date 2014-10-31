# Author: Guy Boertje <https://github.com/guyboertje>
# The license of this source is "New BSD Licence"

require "google_drive/util"
require "google_drive/error"
require "google_drive/row"


module GoogleDrive

  # Provides access to cells using column names.
  # Use GoogleDrive::Worksheet#list to get GoogleDrive::List object.
  #--
  # This is implemented as wrapper of GoogleDrive::Worksheet i.e. using cells
  # feed, not list feed. In this way, we can easily provide consistent API as
  # GoogleDrive::Worksheet using save()/reload().
  class Rows
    include Enumerable

    def initialize(session, worksheet) #:nodoc:
      @session = session
      @worksheet = worksheet
      @feed_url = worksheet.list_feed_url
    end

    def fetch(search = {})
      #e.g. {'reverse' => true, 'startIndex' => 1, 'count': 1}
      actual_url = @feed_url + add_search_query(search)
      puts '----------   ' + actual_url
      doc = @session.request(:get, actual_url)
      doc.css("feed > entry")
    end

    private

    def add_search_query(search)
      return '' if search.size.zero?
      "?#{URI.encode_www_form(search)}"
    end
  end
end
