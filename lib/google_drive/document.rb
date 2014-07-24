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

    # A Document.
    #
    # Use methods in GoogleDrive::Session to get GoogleDrive::Document object.
    class Document < GoogleDrive::Interface

        include(Util)

        SUPPORTED_EXPORT_FORMAT = Set.new(["xls", "csv", "pdf", "ods", "tsv", "html"])

        def initialize(session, feed_url, title = nil) #:nodoc:
          super(session, nil)
          @feed_url = feed_url
          @title = title
        end

        # URL of worksheet-based feed of the document.
        attr_reader(:feed_url)

        # Creates copy of this document with the given title.
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

        # Exports the document in +format+ and returns it as String.
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

        # Exports the document in +format+ as a local file.
        #
        # +format+ can be either "xls", "csv", "pdf", "ods", "tsv" or "html".
        # If +format+ is nil, it is guessed from the file name.
        # In format such as "csv", only the worksheet specified with +worksheet_index+ is exported.
        #
        # e.g.
        #   document.export_as_file("hoge.ods")
        #   document.export_as_file("hoge.csv", nil, 0)
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
          # General downloading API doesn't work for documents because it requires a different
          # authorization token, and it has a bug that it downloads PDF when text/html is
          # requested.
          raise(NotImplementedError,
              "Use export_as_file or export_as_string instead for GoogleDrive::Spreadsheet.")
        end

        def inspect
          fields = {:feed_url => self.feed_url}
          fields[:title] = @title if @title
          return "\#<%p %s>" % [self.class, fields.map(){ |k, v| "%s=%p" % [k, v] }.join(", ")]
        end

    end

end
