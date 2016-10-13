# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require 'time'

require 'google_drive/util'
require 'google_drive/error'
require 'google_drive/worksheet'
require 'google_drive/acl'
require 'google_drive/file'

module GoogleDrive
  # A spreadsheet.
  #
  # Use methods in GoogleDrive::Session to get GoogleDrive::Spreadsheet object.
  class Spreadsheet < GoogleDrive::File
    include(Util)

    SUPPORTED_EXPORT_FORMAT = Set.new(%w(xlsx csv pdf))

    # Key of the spreadsheet.
    def key
      id
    end

    # URL of worksheet-based feed of the spreadsheet.
    def worksheets_feed_url
      'https://spreadsheets.google.com/feeds/worksheets/%s/private/full' %
        id
    end

    # URL of feed used in the deprecated document list feed API.
    def document_feed_url
      'https://docs.google.com/feeds/documents/private/full/' + CGI.escape(resource_id)
    end

    # Spreadsheet feed URL of the spreadsheet.
    def spreadsheet_feed_url
      'https://spreadsheets.google.com/feeds/spreadsheets/private/full/' + id
    end

    # Returns worksheets of the spreadsheet as array of GoogleDrive::Worksheet.
    def worksheets
      doc = @session.request(:get, worksheets_feed_url)
      if doc.root.name != 'feed'
        fail(GoogleDrive::Error,
             "%s doesn't look like a worksheets feed URL because its root is not <feed>." %
             worksheets_feed_url)
      end
      doc.css('entry').map { |e| Worksheet.new(@session, self, e) }.freeze
    end

    # Returns a GoogleDrive::Worksheet with the given title in the spreadsheet.
    #
    # Returns nil if not found. Returns the first one when multiple worksheets with the
    # title are found.
    def worksheet_by_title(title)
      worksheets.find { |ws| ws.title == title }
    end

    # Returns a GoogleDrive::Worksheet with the given gid.
    #
    # Returns nil if not found.
    def worksheet_by_gid(gid)
      gid = gid.to_s
      worksheets.find { |ws| ws.gid == gid }
    end

    def add_worksheet_from_template(title)
      # get access token and client_key(id) from  @session
      byebug
      auth_data = @session.drive.request_options.authorization
      access_token = auth_data.access_token # client_id
      client_id = auth_data.client_id

      # find template key
      template_sheet = worksheet_by_title('template')
      template_sheet_id = template_sheet.gid
      # set sheet key
      spreadsheetId = template_sheet.spreadsheet.api_file.id

      # create new work sheet from (template)key
      # set uri
      url = "https://sheets.googleapis.com/v4/spreadsheets/#{spreadsheetId}/sheets/#{template_sheet_id}:copyTo?key=#{client_id}"
      uri = URI.parse(url)

      # create sheme
      header = {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json'
      }

      body = {
        'destinationSpreadsheetId' => spreadsheetId
      }.to_json

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      req = Net::HTTP::Post.new(uri.path, header)
      req.body = body
      p res = https.request(req)
      # return ss
      new_sheet_id = JSON::parse(res.body)['sheetId']
      worksheet_by_gid(new_sheet_id)
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
      doc = @session.request(:post, worksheets_feed_url, data: xml)
      Worksheet.new(@session, self, doc.root)
    end
  end
end
