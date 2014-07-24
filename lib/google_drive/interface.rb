# The license of this source is "New BSD Licence"

require "google_drive/error"


module GoogleDrive

  # Provide a communication interface for modules Document and Spreadsheet
  class Interface < GoogleDrive::File

    # Title of the document or spreadsheet.
    #
    # Set <tt>params[:reload]</tt> to true to force reloading the title.
    def title(params = {})
      if !@title || params[:reload]
        @title = feed_entry(params).css("title").text
      end
      return @title
    end

    # Key of the document or spreadsheet.
    def key
      if @feed_url.scan('docs').any?
        if !(@feed_url =~ %r{^https?://docs.google.com/feeds/default/private/full/document%3A(.*)\?.*$})
          raise(GoogleDrive::Error, "Feed URL is in unknown format: #{@feed_url}")
        end
        return $1
      elsif @feed_url.scan('spreadsheets').any?
        if !(@feed_url =~ %r{^https?://spreadsheets.google.com/feeds/worksheets/(.*)/private/.*$})
          raise(GoogleDrive::Error, "Feed URL is in unknown format: #{@feed_url}")
        end
        return $1
      end
    end

    # URL of feed used in document list feed API.
    def document_feed_url
      return "https://docs.google.com/feeds/default/private/full/document%3A#{self.key}?v=3"
    end

    # Spreadsheet feed URL of the spreadsheet.
    def spreadsheet_feed_url
      return "https://spreadsheets.google.com/feeds/spreadsheets/private/full/#{self.key}"
    end

    # URL which you can open the document or spreadsheet in a Web browser with.
    def human_url
      # Uses Document feed because Spreadsheet feed returns wrong URL for Apps account.
      return self.feed_entry.css("link[rel='alternate']")[0]["href"]
    end

    # <entry> element of document feed as Nokogiri::XML::Element.
    #
    # Set <tt>params[:reload]</tt> to true to force reloading the feed.
    def feed_entry(params = {})
      if !@feed_entry || params[:reload]
        @feed_entry =
            @session.request(:get, self.document_feed_url).css("entry")[0]
      end
      return @feed_entry
    end

    # <entry> element of document list feed as Nokogiri::XML::Element.
    #
    # Set <tt>params[:reload]</tt> to true to force reloading the feed.
    def feed_entry(params = {})
      if !@feed_entry || params[:reload]
        @feed_entry =
            @session.request(:get, self.document_feed_url, :auth => :writely).css("entry")[0]
      end
      return @feed_entry
    end

  end
end