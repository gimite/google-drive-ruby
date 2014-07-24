# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "time"

require "google_drive/util"
require "google_drive/error"
require "google_drive/worksheet"
require "google_drive/table"
require "google_drive/acl"
require "google_drive/file"
require "google_drive/interface"


module GoogleDrive
    
    # A spreadsheet.
    #
    # Use methods in GoogleDrive::Session to get GoogleDrive::Spreadsheet object.
    class Spreadsheet < GoogleDrive::Interface

        include(Util)
        
        SUPPORTED_EXPORT_FORMAT = Set.new(["xls", "csv", "pdf", "ods", "tsv", "html"])

        def initialize(session, feed_url, title = nil) #:nodoc:
          super(session, nil)
          @feed_url = feed_url
          @title = title
        end

        # URL of worksheet-based feed of the spreadsheet.
        attr_reader(:feed_url)

        # DEPRECATED: Table and Record feeds are deprecated and they will not be available after
        # March 2012.
        #
        # Tables feed URL of the spreadsheet.
        def tables_feed_url
          warn(
              "DEPRECATED: Google Spreadsheet Table and Record feeds are deprecated and they " +
              "will not be available after March 2012.")
          return "https://spreadsheets.google.com/feeds/#{self.key}/tables"
        end
        
        # Creates copy of this spreadsheet with the given title.
        def duplicate(new_title = nil)
          new_title ||= (self.title ? "Copy of " + self.title : "Untitled")
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml;charset=utf-8"}
          xml = <<-"EOS"
            <entry xmlns='http://www.w3.org/2005/Atom'>
              <id>#{h(self.document_feed_url)}</id>
              <title>#{h(new_title)}</title>
            </entry>
          EOS
          doc = @session.request(
              :post, DOCS_BASE_URL, :data => xml, :header => header, :auth => :writely)
          ss_url = doc.css(
              "link[rel='http://schemas.google.com/spreadsheets/2006#worksheetsfeed']")[0]["href"]
          return Spreadsheet.new(@session, ss_url, new_title)
        end

        # Exports the spreadsheet in +format+ and returns it as String.
        #
        # +format+ can be either "xls", "csv", "pdf", "ods", "tsv" or "html".
        # In format such as "csv", only the worksheet specified with +worksheet_index+ is
        # exported.
        def export_as_string(format, worksheet_index = nil)
          gid_param = worksheet_index ? "&gid=#{worksheet_index}" : ""
          format_string = "&format=#{format}"
          if self.human_url.match("edit")
            url = self.human_url.gsub(/edit/, "export") + gid_param + format_string
          else
            url =
              "https://spreadsheets.google.com/feeds/download/spreadsheets/Export" +
              "?key=#{key}&exportFormat=#{format}#{gid_param}"
          end
          return @session.request(:get, url, :response_type => :raw)
        end
        
        # Exports the spreadsheet in +format+ as a local file.
        #
        # +format+ can be either "xls", "csv", "pdf", "ods", "tsv" or "html".
        # If +format+ is nil, it is guessed from the file name.
        # In format such as "csv", only the worksheet specified with +worksheet_index+ is exported.
        #
        # e.g.
        #   spreadsheet.export_as_file("hoge.ods")
        #   spreadsheet.export_as_file("hoge.csv", nil, 0)
        def export_as_file(local_path, format = nil, worksheet_index = nil)
          if !format
            format = ::File.extname(local_path).gsub(/^\./, "")
            if !SUPPORTED_EXPORT_FORMAT.include?(format)
              raise(ArgumentError,
                  ("Cannot guess format from the file name: %s\n" +
                   "Specify format argument explicitly.") %
                  local_path)
            end
          end
          open(local_path, "wb") do |f|
            f.write(export_as_string(format, worksheet_index))
          end
        end
        
        def download_to_io(io, params = {})
          # General downloading API doesn't work for spreadsheets because it requires a different
          # authorization token, and it has a bug that it downloads PDF when text/html is
          # requested.
          raise(NotImplementedError,
              "Use export_as_file or export_as_string instead for GoogleDrive::Spreadsheet.")
        end
        
        # Returns worksheets of the spreadsheet as array of GoogleDrive::Worksheet.
        def worksheets
          doc = @session.request(:get, @feed_url)
          if doc.root.name != "feed"
            raise(GoogleDrive::Error,
                "%s doesn't look like a worksheets feed URL because its root is not <feed>." %
                @feed_url)
          end
          result = []
          doc.css("entry").each() do |entry|
            title = entry.css("title").text
            updated = Time.parse(entry.css("updated").text)
            url = entry.css(
              "link[rel='http://schemas.google.com/spreadsheets/2006#cellsfeed']")[0]["href"]
            result.push(Worksheet.new(@session, self, url, title, updated))
          end
          return result.freeze()
        end
        
        # Returns a GoogleDrive::Worksheet with the given title in the spreadsheet.
        #
        # Returns nil if not found. Returns the first one when multiple worksheets with the
        # title are found.
        def worksheet_by_title(title)
          return self.worksheets.find(){ |ws| ws.title == title }
        end

        # Adds a new worksheet to the spreadsheet. Returns added GoogleDrive::Worksheet.
        def add_worksheet(title, max_rows = 100, max_cols = 20)
          xml = <<-"EOS"
            <entry xmlns='http://www.w3.org/2005/Atom'
                   xmlns:gs='http://schemas.google.com/spreadsheets/2006'>
              <title>#{h(title)}</title>
              <gs:rowCount>#{h(max_rows)}</gs:rowCount>
              <gs:colCount>#{h(max_cols)}</gs:colCount>
            </entry>
          EOS
          doc = @session.request(:post, @feed_url, :data => xml)
          url = doc.css(
            "link[rel='http://schemas.google.com/spreadsheets/2006#cellsfeed']")[0]["href"]
          return Worksheet.new(@session, self, url, title)
        end

        # DEPRECATED: Table and Record feeds are deprecated and they will not be available after
        # March 2012.
        #
        # Returns list of tables in the spreadsheet.
        def tables
          warn(
              "DEPRECATED: Google Spreadsheet Table and Record feeds are deprecated and they " +
              "will not be available after March 2012.")
          doc = @session.request(:get, self.tables_feed_url)
          return doc.css("entry").map(){ |e| Table.new(@session, e) }.freeze()
        end
        
        def inspect
          fields = {:feed_url => self.feed_url}
          fields[:title] = @title if @title
          return "\#<%p %s>" % [self.class, fields.map(){ |k, v| "%s=%p" % [k, v] }.join(", ")]
        end
        
    end
    
end
