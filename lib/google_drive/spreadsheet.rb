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
  # e.g., Use methods spreadsheet_by_title, spreadsheet_by_url,
  # create_spreadsheet in GoogleDrive::Session to get GoogleDrive::Spreadsheet
  # object.
  class Spreadsheet < GoogleDrive::File
    
    # TODO: Bump up the major version before switching the existing methods to
    # v4 API because it requires to turn on a new API in the API console.

    include(Util)

    SUPPORTED_EXPORT_FORMAT = Set.new(%w[xlsx csv pdf])

    # Key of the spreadsheet.
    def key
      id
    end
    
    # URL of worksheet-based feed of the spreadsheet.
    def worksheets_feed_url
      format(
        'https://spreadsheets.google.com/feeds/worksheets/%s/private/full', id
      )
    end

    # URL of feed used in the deprecated document list feed API.
    def document_feed_url
      'https://docs.google.com/feeds/documents/private/full/' +
        CGI.escape(resource_id)
    end

    # Spreadsheet feed URL of the spreadsheet.
    def spreadsheet_feed_url
      'https://spreadsheets.google.com/feeds/spreadsheets/private/full/' + id
    end

    # Returns worksheets of the spreadsheet as array of GoogleDrive::Worksheet.
    def worksheets
      doc = @session.request(:get, worksheets_feed_url)
      if doc.root.name != 'feed'
        raise(GoogleDrive::Error,
              format(
                "%s doesn't look like a worksheets feed URL because its root " \
                'is not <feed>.',
                worksheets_feed_url
              ))
      end
      doc.css('entry').map { |e| Worksheet.new(@session, self, e) }.freeze
    end

    # Returns a GoogleDrive::Worksheet with the given title in the spreadsheet.
    #
    # Returns nil if not found. Returns the first one when multiple worksheets
    # with the title are found.
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

    # Adds a new worksheet to the spreadsheet. Returns added
    # GoogleDrive::Worksheet.
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

    # @api private
    # This method is currently alpha, and will likely change in the future.
    def add_worksheet_v4(title, position_index = 0)
      # TODO: Let this method return Worksheet instance and merge it with add_worksheet.
      batch_update([{
        add_sheet: Google::Apis::SheetsV4::AddSheetRequest.new(
          properties: Google::Apis::SheetsV4::SheetProperties.new(
            title: title,
            index: position_index
          )
        ),
      }])
    end

    # @api private
    # This method is currently alpha, and will likely change in the future.
    def delete_worksheet(id)
      batch_update([{
        delete_sheet: Google::Apis::SheetsV4::DeleteSheetRequest.new(sheet_id: id),
      }])
    end

    # Not available for GoogleDrive::Spreadsheet. Use export_as_file instead.
    def download_to_file(_path, _params = {})
      raise(
        NotImplementedError,
        'download_to_file is not available for GoogleDrive::Spreadsheet. ' \
        'Use export_as_file instead.'
      )
    end

    # Not available for GoogleDrive::Spreadsheet. Use export_as_string instead.
    def download_to_string(_params = {})
      raise(
        NotImplementedError,
        'download_to_string is not available for GoogleDrive::Spreadsheet. ' \
        'Use export_as_string instead.'
      )
    end

    # Not available for GoogleDrive::Spreadsheet. Use export_to_io instead.
    def download_to_io(_io, _params = {})
      raise(
        NotImplementedError,
        'download_to_io is not available for GoogleDrive::Spreadsheet. ' \
        'Use export_to_io instead.'
      )
    end

    # @api private
    def batch_update(requests)
      batch_request = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new(requests: requests)
      @session.sheets_service.batch_update_spreadsheet(id, batch_request)
    end
  end
end
