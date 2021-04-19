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
      api_spreadsheet = @session.sheets_service.get_spreadsheet(id, fields: 'sheets.properties')
      api_spreadsheet.sheets.map{ |s| Worksheet.new(@session, self, s.properties) }
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
    def worksheet_by_sheet_id(sheet_id)
      sheet_id = sheet_id.to_i
      worksheets.find { |ws| ws.sheet_id == sheet_id }
    end

    alias worksheet_by_gid worksheet_by_sheet_id

    # Adds a new worksheet to the spreadsheet. Returns added
    # GoogleDrive::Worksheet.
    #
    # When +index+ is specified, the worksheet is inserted at the given
    # +index+.
    def add_worksheet(title, max_rows = 100, max_cols = 20, index: nil)
      (response,) = batch_update([{
        add_sheet: {
          properties: {
            title: title,
            index: index,
            grid_properties: {
              row_count: max_rows,
              column_count: max_cols,
            },
          },
        },
      }])
      Worksheet.new(@session, self, response.add_sheet.properties)
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

    # Performs batch update of the spreadsheet.
    #
    # +requests+ is an Array of Google::Apis::SheetsV4::Request or its Hash
    # equivalent. Returns an Array of Google::Apis::SheetsV4::Response.
    def batch_update(requests)
      batch_request =
        Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new(
          requests: requests)
      batch_response =
        @session.sheets_service.batch_update_spreadsheet(id, batch_request)
      batch_response.replies
    end

    # Append values to a spreadsheet by first searching for a data table at a range,
    # then appending the specified values at the end of this data table.
    #
    # +range+ The A1 notation of a range to search for a logical table of data. 
    # Values will be appended after the last row of the table.
    # +values+ Array (rows) of Array (columns) of values to append to the spreadsheet.
    # +override_params+ allows you to control how the values will be inserted.
    #   By default, the values will be interpreted as if typed by a user, 
    #   and will add new rows instead of ovewriting existing ones.
    #   So default value is `{ value_input_option: 'USER_ENTERED', insert_data_option: 'INSERT_ROWS' }`
    #   See https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets.values/append#query-parameters for more information
    #
    # Returns an object +UpdateValuesResponse+ that documents the modifications done 
    # to your spreadsheet.
    #   
    # You can read the Google documentation for more information:
    #   https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets.values/append
    #
    # Example: 
    #   sheet.append_values "A1", [ [ 10, 11, 12 ], [ 20, 21, 22 ] ]
    # 
    def append_values(range_name, values, override_params = {})
      value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
      default_params = {
        value_input_option: 'USER_ENTERED',
        insert_data_option: 'INSERT_ROWS',
      }
      request_body = default_params.merge(override_params)
      result = @session.sheets_service.append_spreadsheet_value(id, range_name, value_range, request_body)
      result.updates
    end
  end
end
