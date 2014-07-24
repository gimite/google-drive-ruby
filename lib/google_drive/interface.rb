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
        @title = document_feed_entry(params).css("title").text
      end
      return @title
    end

    # Key of the document or spreadsheet.
    def key
      if !(@docs_feed_url =~
          %r{^https?://docs.google.com/feeds/default/private/full/document%3A(.*)\?.*$})
        raise(GoogleDrive::Error, "Documents feed URL is in unknown format: #{@docs_feed_url}")
      end
      return $1
    end

    # feed URL of the document or spreadsheet.
    def document_feed_url
      return "https://docs.google.com/feeds/default/private/full/document%3A#{self.key}?v=3"
    end

    # URL which you can open the document or spreadsheet in a Web browser with.
    def human_url
      # Uses Document feed because Spreadsheet feed returns wrong URL for Apps account.
      return self.document_feed_entry.css("link[rel='alternate']")[0]["href"]
    end


    # URL of feed used in document list feed API.
    def document_feed_url
      return "https://docs.google.com/feeds/default/private/full/document%3A#{self.key}?v=3"
    end

    # <entry> element of document feed as Nokogiri::XML::Element.
    #
    # Set <tt>params[:reload]</tt> to true to force reloading the feed.
    def document_feed_entry(params = {})
      if !@document_feed_entry || params[:reload]
        @document_feed_entry =
            @session.request(:get, self.document_feed_url).css("entry")[0]
      end
      return @document_feed_entry
    end

    # <entry> element of document list feed as Nokogiri::XML::Element.
    #
    # Set <tt>params[:reload]</tt> to true to force reloading the feed.
    def document_feed_entry(params = {})
      if !@document_feed_entry || params[:reload]
        @document_feed_entry =
            @session.request(:get, self.document_feed_url, :auth => :writely).css("entry")[0]
      end
      return @document_feed_entry
    end

  end
end