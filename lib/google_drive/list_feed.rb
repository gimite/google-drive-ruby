# Author: Bashanta Dahal <https://github.com/bashantad>
# The license of this source is "New BSD Licence"

require "cgi"
require "uri"

require "google_drive/util"
require "google_drive/error"

module GoogleDrive

  # A ListFeed (i.e. a row) in a worksheet.
  # Use GoogleDrive::WorkSheet#list_feeds to get GoogleDrive::ListFeed object.
  class ListFeed

    include(Util)

    def initialize(session, worksheet, list_feed_entry) #:nodoc:
      @session = session
      @worksheet = worksheet
      @list_feed_entry = list_feed_entry
    end

    # Nokogiri::XML::Element object of the <entry> element in a list_feeds.
    attr_reader(:list_feed_entry)

    def row_url
      return @list_feed_entry.css("link").attr("href").value
    end

    # Deletes this row.
    def delete
      @session.request(:delete, row_url)
    end

    def attributes
      @list_feed_entry.children.collect(&:name)
    end

  end

end
