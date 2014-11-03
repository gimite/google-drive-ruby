# Author: Guy Boertje <https://github.com/guyboertje>
# The license of this source is "New BSD Licence"

require "google_drive/util"
require "google_drive/error"
require "google_drive/query"
require "google_drive/list_query"
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

    def self.columnize(column)
      # The keys are the header values of the worksheet lowercased and with all non-alpha-numeric characters removed
      column.gsub(/\p{^Alnum}/, '').downcase
    end

    attr_reader :feed_url, :append_url

    def initialize(session, worksheet) #:nodoc:
      @session = session
      @worksheet = worksheet
      @feed_url = worksheet.list_feed_url
      @rows = []
    end

    def fetch(query = Query.new(@feed_url))
      @rows.clear
      doc = @session.request(:get, query.to_url)
      doc.css('feed > entry').each do |entry|
        @rows.push Row.build(entry).with_list(self)
      end
      @append_url = doc.at_css("link[rel='http://schemas.google.com/g/2005#post']")['href']
      self
    end

    def each &block
      @rows.each &block
    end

    def upload_insert(row)
      @session.request(:post, append_url, :data => row.as_insert_xml)
    end

    def upload_update(row)
      @session.request(:put, row.edit_url, :data => row.as_update_xml, :header => {"Content-Type" => "application/atom+xml;charset=utf-8", "If-Match" => "*"})
    end

    def new_query
      ListQuery.new(@feed_url)
    end

    def columnize(str)
      self.class.columnize(str)
    end
  end
end
