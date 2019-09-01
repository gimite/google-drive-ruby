# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require 'cgi'
require 'set'
require 'uri'

require 'google_drive/util'
require 'google_drive/error'
require 'google_drive/list'

module GoogleDrive
  # A worksheet (i.e. a tab) in a spreadsheet.
  # Use GoogleDrive::Spreadsheet#worksheets to get GoogleDrive::Worksheet
  # object.
  class Worksheet
    include(Util)

    # A few default color instances that match the colors from the Google Sheets web UI.
    #
    # TODO: Add more colors from
    # https://github.com/denilsonsa/gimp-palettes/blob/master/palettes/Google-Drive.gpl
    module Colors
      RED = Google::Apis::SheetsV4::Color.new(red: 1.0)
      DARK_RED_1 = Google::Apis::SheetsV4::Color.new(red: 0.8)
      RED_BERRY = Google::Apis::SheetsV4::Color.new(red: 0.596)
      DARK_RED_BERRY_1 = Google::Apis::SheetsV4::Color.new(red: 0.659, green: 0.11)
      ORANGE = Google::Apis::SheetsV4::Color.new(red: 1.0, green: 0.6)
      DARK_ORANGE_1 = Google::Apis::SheetsV4::Color.new(red: 0.9, green: 0.569, blue: 0.22)
      YELLOW = Google::Apis::SheetsV4::Color.new(red: 1.0, green: 1.0)
      DARK_YELLOW_1 = Google::Apis::SheetsV4::Color.new(red: 0.945, green: 0.76, blue: 0.196)
      GREEN = Google::Apis::SheetsV4::Color.new(green: 1.0)
      DARK_GREEN_1 = Google::Apis::SheetsV4::Color.new(red: 0.416, green: 0.659, blue: 0.31)
      CYAN = Google::Apis::SheetsV4::Color.new(green: 1.0, blue: 1.0)
      DARK_CYAN_1 = Google::Apis::SheetsV4::Color.new(red: 0.27, green: 0.506, blue: 0.557)
      CORNFLOWER_BLUE = Google::Apis::SheetsV4::Color.new(red: 0.29, green: 0.525, blue: 0.91)
      DARK_CORNFLOWER_BLUE_1 = Google::Apis::SheetsV4::Color.new(red: 0.235, green: 0.47, blue: 0.847)
      BLUE = Google::Apis::SheetsV4::Color.new(blue: 1.0)
      DARK_BLUE_1 = Google::Apis::SheetsV4::Color.new(red: 0.239, green: 0.522, blue: 0.776)
      PURPLE = Google::Apis::SheetsV4::Color.new(red: 0.6, blue: 1.0)
      DARK_PURPLE_1 = Google::Apis::SheetsV4::Color.new(red: 0.404, green: 0.306, blue: 0.655)
      MAGENTA = Google::Apis::SheetsV4::Color.new(red: 1.0, blue: 1.0)
      DARK_MAGENTA_1 = Google::Apis::SheetsV4::Color.new(red: 0.651, green: 0.302, blue: 0.475)
      WHITE = Google::Apis::SheetsV4::Color.new(red: 1.0, green: 1.0, blue: 1.0)
      BLACK = Google::Apis::SheetsV4::Color.new(red: 0.0, green: 0.0, blue: 0.0)
      GRAY = Google::Apis::SheetsV4::Color.new(red: 0.8, green: 0.8, blue: 0.8)
      DARK_GRAY_1 = Google::Apis::SheetsV4::Color.new(red: 0.714, green: 0.714, blue: 0.714)
    end

    # @api private
    # A regexp which matches an invalid character in XML 1.0:
    # https://en.wikipedia.org/wiki/Valid_characters_in_XML#XML_1.0
    XML_INVALID_CHAR_REGEXP =
      /[^\u0009\u000a\u000d\u0020-\ud7ff\ue000-\ufffd\u{10000}-\u{10ffff}]/

    # @api private
    def initialize(session, spreadsheet, properties)
      @session = session
      @spreadsheet = spreadsheet
      set_properties(properties)
      @cells = nil
      @input_values = nil
      @numeric_values = nil
      @modified = Set.new
      @list = nil
      @v4_requests = []
    end

    # Nokogiri::XML::Element object of the <entry> element in a worksheets feed.
    #
    # DEPRECATED: This method is deprecated, and now requires additional
    # network fetch. Consider using properties instead.
    def worksheet_feed_entry
      @worksheet_feed_entry ||= @session.request(:get, worksheet_feed_url).root
    end

    # Google::Apis::SheetsV4::SheetProperties object for this worksheet.
    attr_reader :properties

    # Title of the worksheet (shown as tab label in Web interface).
    attr_reader :title

    # Index of the worksheet (affects tab order in web interface).
    attr_reader :index

    # GoogleDrive::Spreadsheet which this worksheet belongs to.
    attr_reader :spreadsheet

    # Time object which represents the time the worksheet was last updated.
    #
    # DEPRECATED: From google_drive 3.0.0, it returns the time the
    # *spreadsheet* was last updated, instead of the worksheet. This is because
    # it looks the information is not available in Sheets v4 API.
    def updated
      spreadsheet.modified_time.to_time
    end

    # URL of cell-based feed of the worksheet.
    #
    # DEPRECATED: This method is deprecated, and now requires additional
    # network fetch.
    def cells_feed_url
      worksheet_feed_entry.css(
        "link[rel='http://schemas.google.com/spreadsheets/2006#cellsfeed']"
      )[0]['href']
    end

    # URL of worksheet feed URL of the worksheet.
    def worksheet_feed_url
      return '%s/%s' % [spreadsheet.worksheets_feed_url, worksheet_feed_id]
    end

    # URL to export the worksheet as CSV.
    def csv_export_url
      'https://docs.google.com/spreadsheets/d/%s/export?gid=%s&format=csv' %
        [spreadsheet.id, gid]
    end

    # Exports the worksheet as String in CSV format.
    def export_as_string
      @session.request(:get, csv_export_url, response_type: :raw)
    end

    # Exports the worksheet to +path+ in CSV format.
    def export_as_file(path)
      data = export_as_string
      open(path, 'wb') { |f| f.write(data) }
    end

    # ID of the worksheet.
    def sheet_id
      @properties.sheet_id
    end

    # Returns sheet_id.to_s.
    def gid
      sheet_id.to_s
    end

    # URL to view/edit the worksheet in a Web browser.
    def human_url
      format("%s\#gid=%s", spreadsheet.human_url, gid)
    end

    # Copy worksheet to specified spreadsheet.
    # This method can take either instance of GoogleDrive::Spreadsheet or its id.
    def copy_to(spreadsheet_or_id)
      destination_spreadsheet_id =
        spreadsheet_or_id.respond_to?(:id) ?
          spreadsheet_or_id.id : spreadsheet_or_id
      request = Google::Apis::SheetsV4::CopySheetToAnotherSpreadsheetRequest.new(
        destination_spreadsheet_id: destination_spreadsheet_id,
      )
      @session.sheets_service.copy_spreadsheet(spreadsheet.id, sheet_id, request)
      nil
    end

    # Copy worksheet to owner spreadsheet.
    def duplicate
      copy_to(spreadsheet)
    end

    # Returns content of the cell as String. Arguments must be either
    # (row number, column number) or cell name. Top-left cell is [1, 1].
    #
    # e.g.
    #   worksheet[2, 1]  #=> "hoge"
    #   worksheet["A2"]  #=> "hoge"
    def [](*args)
      (row, col) = parse_cell_args(args)
      cells[[row, col]] || ''
    end

    # Updates content of the cell.
    # Arguments in the bracket must be either (row number, column number) or
    # cell name. Note that update is not sent to the server until you call
    # save().
    # Top-left cell is [1, 1].
    #
    # e.g.
    #   worksheet[2, 1] = "hoge"
    #   worksheet["A2"] = "hoge"
    #   worksheet[1, 3] = "=A1+B1"
    def []=(*args)
      (row, col) = parse_cell_args(args[0...-1])
      value = args[-1].to_s
      validate_cell_value(value)
      reload_cells unless @cells
      @cells[[row, col]] = value
      @input_values[[row, col]] = value
      @numeric_values[[row, col]] = nil
      @modified.add([row, col])
      self.max_rows = row if row > @max_rows
      self.max_cols = col if col > @max_cols
      if value.empty?
        @num_rows = nil
        @num_cols = nil
      else
        @num_rows = row if @num_rows && row > @num_rows
        @num_cols = col if @num_cols && col > @num_cols
      end
    end

    # Updates cells in a rectangle area by a two-dimensional Array.
    # +top_row+ and +left_col+ specifies the top-left corner of the area.
    #
    # e.g.
    #   worksheet.update_cells(2, 3, [["1", "2"], ["3", "4"]])
    def update_cells(top_row, left_col, darray)
      darray.each_with_index do |array, y|
        array.each_with_index do |value, x|
          self[top_row + y, left_col + x] = value
        end
      end
    end

    # Returns the value or the formula of the cell. Arguments must be either
    # (row number, column number) or cell name. Top-left cell is [1, 1].
    #
    # If user input "=A1+B1" to cell [1, 3]:
    #   worksheet[1, 3]              #=> "3" for example
    #   worksheet.input_value(1, 3)  #=> "=RC[-2]+RC[-1]"
    def input_value(*args)
      (row, col) = parse_cell_args(args)
      reload_cells unless @cells
      @input_values[[row, col]] || ''
    end

    # Returns the numeric value of the cell. Arguments must be either
    # (row number, column number) or cell name. Top-left cell is [1, 1].
    #
    # e.g.
    #   worksheet[1, 3]
    #   #=> "3,0"  # it depends on locale, currency...
    #   worksheet.numeric_value(1, 3)
    #   #=> 3.0
    #
    # Returns nil if the cell is empty or contains non-number.
    #
    # If you modify the cell, its numeric_value is nil until you call save()
    # and reload().
    #
    # For details, see:
    # https://developers.google.com/google-apps/spreadsheets/#working_with_cell-based_feeds
    def numeric_value(*args)
      (row, col) = parse_cell_args(args)
      reload_cells unless @cells
      @numeric_values[[row, col]]
    end

    # Row number of the bottom-most non-empty row.
    def num_rows
      reload_cells unless @cells
      # Memoizes it because this can be bottle-neck.
      # https://github.com/gimite/google-drive-ruby/pull/49
      @num_rows ||=
        @input_values
        .reject { |(_r, _c), v| v.empty? }
        .map { |(r, _c), _v| r }
        .max ||
        0
    end

    # Column number of the right-most non-empty column.
    def num_cols
      reload_cells unless @cells
      # Memoizes it because this can be bottle-neck.
      # https://github.com/gimite/google-drive-ruby/pull/49
      @num_cols ||=
        @input_values
        .reject { |(_r, _c), v| v.empty? }
        .map { |(_r, c), _v| c }
        .max ||
        0
    end

    # Number of rows including empty rows.
    attr_reader :max_rows

    # Updates number of rows.
    # Note that update is not sent to the server until you call save().
    def max_rows=(rows)
      @max_rows = rows
      @meta_modified = true
    end

    # Number of columns including empty columns.
    attr_reader :max_cols

    # Updates number of columns.
    # Note that update is not sent to the server until you call save().
    def max_cols=(cols)
      @max_cols = cols
      @meta_modified = true
    end

    # Updates title of the worksheet.
    # Note that update is not sent to the server until you call save().
    def title=(title)
      @title = title
      @meta_modified = true
    end

    # Updates index of the worksheet.
    # Note that update is not sent to the server until you call save().
    def index=(index)
      @index = index
      @meta_modified = true
    end

    # @api private
    def cells
      reload_cells unless @cells
      @cells
    end

    # An array of spreadsheet rows. Each row contains an array of
    # columns. Note that resulting array is 0-origin so:
    #
    #   worksheet.rows[0][0] == worksheet[1, 1]
    def rows(skip = 0)
      nc = num_cols
      result = ((1 + skip)..num_rows).map do |row|
        (1..nc).map { |col| self[row, col] }.freeze
      end
      result.freeze
    end

    # Inserts rows.
    #
    # e.g.
    #   # Inserts 2 empty rows before row 3.
    #   worksheet.insert_rows(3, 2)
    #   # Inserts 2 rows with values before row 3.
    #   worksheet.insert_rows(3, [["a, "b"], ["c, "d"]])
    #
    # Note that this method is implemented by shifting all cells below the row.
    # Its behavior is different from inserting rows on the web interface if the
    # worksheet contains inter-cell reference.
    def insert_rows(row_num, rows)
      rows = Array.new(rows, []) if rows.is_a?(Integer)

      # Shifts all cells below the row.
      self.max_rows += rows.size
      num_rows.downto(row_num) do |r|
        (1..num_cols).each do |c|
          self[r + rows.size, c] = input_value(r, c)
        end
      end

      # Fills in the inserted rows.
      num_cols = self.num_cols
      rows.each_with_index do |row, r|
        (0...[row.size, num_cols].max).each do |c|
          self[row_num + r, 1 + c] = row[c] || ''
        end
      end
    end

    # Deletes rows.
    #
    # e.g.
    #   # Deletes 2 rows starting from row 3 (i.e., deletes row 3 and 4).
    #   worksheet.delete_rows(3, 2)
    #
    # Note that this method is implemented by shifting all cells below the row.
    # Its behavior is different from deleting rows on the web interface if the
    # worksheet contains inter-cell reference.
    def delete_rows(row_num, rows)
      if row_num + rows - 1 > self.max_rows
        raise(ArgumentError, 'The row number is out of range')
      end
      for r in row_num..(self.max_rows - rows)
        for c in 1..num_cols
          self[r, c] = input_value(r + rows, c)
        end
      end
      self.max_rows -= rows
    end

    # Reloads content of the worksheets from the server.
    # Note that changes you made by []= etc. is discarded if you haven't called
    # save().
    def reload
      api_spreadsheet =
        @session.sheets_service.get_spreadsheet(
          spreadsheet.id,
          ranges: "'%s'" % @title,
          fields:
            'sheets(properties,data.rowData.values' \
            '(formattedValue,userEnteredValue,effectiveValue))'
        )
      api_sheet = api_spreadsheet.sheets[0]
      set_properties(api_sheet.properties)
      update_cells_from_api_sheet(api_sheet)
      @v4_requests = []
      @worksheet_feed_entry = nil
      true
    end

    # Saves your changes made by []=, etc. to the server.
    def save
      sent = false

      if @meta_modified
        add_request({
          update_sheet_properties: {
            properties: {
              sheet_id: sheet_id,
              title: title,
              index: index,
              grid_properties: {row_count: max_rows, column_count: max_cols},
            },
            fields: '*',
          },
        })
      end

      if !@v4_requests.empty?
        self.spreadsheet.batch_update(@v4_requests)
        @v4_requests = []
        sent = true
      end

      @remote_title = @title

      unless @modified.empty?
        min_modified_row = 1.0 / 0.0
        max_modified_row = 0
        min_modified_col = 1.0 / 0.0
        max_modified_col = 0
        @modified.each do |r, c|
          min_modified_row = r if r < min_modified_row
          max_modified_row = r if r > max_modified_row
          min_modified_col = c if c < min_modified_col
          max_modified_col = c if c > max_modified_col
        end

        # Uses update_spreadsheet_value instead batch_update_spreadsheet with
        # update_cells. batch_update_spreadsheet has benefit that the request
        # can be batched with other requests. But it has drawback that the
        # type of the value (string_value, number_value, etc.) must be
        # explicitly specified in user_entered_value. Since I don't know exact
        # logic to determine the type from text, I chose to use
        # update_spreadsheet_value here.
        range = "'%s'!R%dC%d:R%dC%d" %
            [@title, min_modified_row, min_modified_col, max_modified_row, max_modified_col]
        values = (min_modified_row..max_modified_row).map do |r|
          (min_modified_col..max_modified_col).map do |c|
            @modified.include?([r, c]) ? (@cells[[r, c]] || '') : nil
          end
        end
        value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
        @session.sheets_service.update_spreadsheet_value(
            spreadsheet.id, range, value_range, value_input_option: 'USER_ENTERED')

        @modified.clear
        sent = true
      end

      sent
    end

    # Calls save() and reload().
    def synchronize
      save
      reload
    end

    # Deletes this worksheet. Deletion takes effect right away without calling
    # save().
    def delete
      spreadsheet.batch_update([{
        delete_sheet: Google::Apis::SheetsV4::DeleteSheetRequest.new(sheet_id: sheet_id),
      }])
    end

    # Returns true if you have changes made by []= etc. which haven't been saved.
    def dirty?
      !@modified.empty? || !@v4_requests.empty?
    end

    # List feed URL of the worksheet.
    #
    # DEPRECATED: This method is deprecated, and now requires additional
    # network fetch.
    def list_feed_url
      @worksheet_feed_entry.css(
        "link[rel='http://schemas.google.com/spreadsheets/2006#listfeed']"
      )[0]['href']
    end

    # Provides access to cells using column names, assuming the first row
    # contains column
    # names. Returned object is GoogleDrive::List which you can use mostly as
    # Array of Hash.
    #
    # e.g. Assuming the first row is ["x", "y"]:
    #   worksheet.list[0]["x"]  #=> "1"  # i.e. worksheet[2, 1]
    #   worksheet.list[0]["y"]  #=> "2"  # i.e. worksheet[2, 2]
    #   worksheet.list[1]["x"] = "3"     # i.e. worksheet[3, 1] = "3"
    #   worksheet.list[1]["y"] = "4"     # i.e. worksheet[3, 2] = "4"
    #   worksheet.list.push({"x" => "5", "y" => "6"})
    #
    # Note that update is not sent to the server until you call save().
    def list
      @list ||= List.new(self)
    end

    # Returns a [row, col] pair for a cell name string.
    # e.g.
    #   worksheet.cell_name_to_row_col("C2")  #=> [2, 3]
    def cell_name_to_row_col(cell_name)
      unless cell_name.is_a?(String)
        raise(
          ArgumentError, format('Cell name must be a string: %p', cell_name)
        )
      end
      unless cell_name.upcase =~ /^([A-Z]+)(\d+)$/
        raise(
          ArgumentError,
          format(
            'Cell name must be only letters followed by digits with no ' \
            'spaces in between: %p',
            cell_name
          )
        )
      end
      col = 0
      Regexp.last_match(1).each_byte do |b|
        # 0x41: "A"
        col = col * 26 + (b - 0x41 + 1)
      end
      row = Regexp.last_match(2).to_i
      [row, col]
    end

    def inspect
      fields = { spreadsheet_id: spreadsheet.id, gid: gid }
      fields[:title] = @title if @title
      format(
        "\#<%p %s>",
        self.class,
        fields.map { |k, v| format('%s=%p', k, v) }.join(', ')
      )
    end

    # Merges a range of cells together. "MERGE_COLUMNS" is another option for merge_type
    def merge_cells(top_row, left_col, num_rows, num_cols, merge_type: 'MERGE_ALL')
      range = v4_range_object(top_row, left_col, num_rows, num_cols)
      add_request({
        merge_cells:
          Google::Apis::SheetsV4::MergeCellsRequest.new(
            range: range, merge_type: merge_type),
      })
    end

    # Changes the formatting of a range of cells to match the given number format.
    # For example to change A1 to a percentage with 1 decimal point:
    #   worksheet.set_number_format(1, 1, 1, 1, "##.#%")
    # Google API reference: https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets#numberformat
    def set_number_format(top_row, left_col, num_rows, num_cols, pattern, type: "NUMBER")
      number_format = Google::Apis::SheetsV4::NumberFormat.new(type: type, pattern: pattern)
      format = Google::Apis::SheetsV4::CellFormat.new(number_format: number_format)
      fields = 'userEnteredFormat(numberFormat)'
      format_cells(top_row, left_col, num_rows, num_cols, format, fields)
    end

    # Changes text alignment of a range of cells.
    # Horizontal alignment can be "LEFT", "CENTER", or "RIGHT".
    # Vertical alignment can be "TOP", "MIDDLE", or "BOTTOM".
    # Google API reference: https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets#HorizontalAlign
    def set_text_alignment(
        top_row, left_col, num_rows, num_cols,
        horizontal: nil, vertical: nil)
      return if horizontal.nil? && vertical.nil?

      format = Google::Apis::SheetsV4::CellFormat.new(
        horizontal_alignment: horizontal, vertical_alignment: vertical)
      subfields =
        (horizontal.nil? ? [] : ['horizontalAlignment']) +
        (vertical.nil? ? [] : ['verticalAlignment'])

      fields = 'userEnteredFormat(%s)' % subfields.join(',')
      format_cells(top_row, left_col, num_rows, num_cols, format, fields)
    end

    # Changes the background color on a range of cells. e.g.:
    #   worksheet.set_background_color(1, 1, 1, 1, GoogleDrive::Worksheet::Colors::DARK_YELLOW_1)
    #
    # background_color is an instance of Google::Apis::SheetsV4::Color.
    def set_background_color(top_row, left_col, num_rows, num_cols, background_color)
      format = Google::Apis::SheetsV4::CellFormat.new(background_color: background_color)
      fields = 'userEnteredFormat(backgroundColor)'
      format_cells(top_row, left_col, num_rows, num_cols, format, fields)
    end

    # Change the text formatting on a range of cells. e.g., To set cell
    # A1 to have red text that is bold and italic:
    #   worksheet.set_text_format(
    #     1, 1, 1, 1,
    #     bold: true,
    #     italic: true,
    #     foreground_color: GoogleDrive::Worksheet::Colors::RED_BERRY)
    #
    # foreground_color is an instance of Google::Apis::SheetsV4::Color.
    # Google API reference:
    # https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets#textformat
    def set_text_format(top_row, left_col, num_rows, num_cols, bold: false,
                          italic: false, strikethrough: false, font_size: nil,
                          font_family: nil, foreground_color: nil)
      text_format = Google::Apis::SheetsV4::TextFormat.new(
        bold: bold,
        italic: italic,
        strikethrough: strikethrough,
        font_size: font_size,
        font_family: font_family,
        foreground_color: foreground_color
      )

      format = Google::Apis::SheetsV4::CellFormat.new(text_format: text_format)
      fields = 'userEnteredFormat(textFormat)'
      format_cells(top_row, left_col, num_rows, num_cols, format, fields)
    end

    # Update the border styles for a range of cells.
    # borders is a Hash of Google::Apis::SheetsV4::Border keyed with the
    # following symbols: :top, :bottom, :left, :right, :innerHorizontal, :innerVertical
    # e.g., To set a black double-line on the bottom of A1:
    #   update_borders(
    #     1, 1, 1, 1,
    #     {bottom: Google::Apis::SheetsV4::Border.new(
    #       style: "DOUBLE", color: GoogleDrive::Worksheet::Colors::BLACK)})
    def update_borders(top_row, left_col, num_rows, num_cols, borders)
      request = Google::Apis::SheetsV4::UpdateBordersRequest.new(borders)
      request.range = v4_range_object(top_row, left_col, num_rows, num_cols)
      add_request({update_borders: request})
    end

    # Add an instance of Google::Apis::SheetsV4::Request (or its Hash
    # equivalent) which will be applied on the next call to the save method.
    def add_request(request)
      @v4_requests.push(request)
    end

    # @api private
    def worksheet_feed_id
      gid_int = sheet_id
      xor_val = gid_int > 31578 ? 474 : 31578
      letter = gid_int > 31578 ? 'o' : ''
      letter + (gid_int ^ xor_val).to_s(36)
    end

    private

    def format_cells(top_row, left_col, num_rows, num_cols, format, fields)
      add_request({
        repeat_cell:
          Google::Apis::SheetsV4::RepeatCellRequest.new(
            range: v4_range_object(top_row, left_col, num_rows, num_cols),
            cell: Google::Apis::SheetsV4::CellData.new(user_entered_format: format),
            fields: fields
          ),
      })
    end

    def set_properties(properties)
      @properties = properties
      @title = @remote_title = properties.title
      @index = properties.index
      if properties.grid_properties.nil?
        @max_rows = @max_cols = 0
      else
        @max_rows = properties.grid_properties.row_count
        @max_cols = properties.grid_properties.column_count
      end
      @meta_modified = false
    end

    def reload_cells
      response =
          @session.sheets_service.get_spreadsheet(
              spreadsheet.id,
              ranges: "'%s'" % @remote_title,
              fields: 'sheets.data.rowData.values(formattedValue,userEnteredValue,effectiveValue)'
          )
      update_cells_from_api_sheet(response.sheets[0])
    end

    def update_cells_from_api_sheet(api_sheet)
      rows_data = api_sheet.data[0].row_data || []

      @num_rows = rows_data.size
      @num_cols = 0
      @cells = {}
      @input_values = {}
      @numeric_values = {}

      rows_data.each_with_index do |row_data, r|
        next if !row_data.values
        @num_cols = row_data.values.size if row_data.values.size > @num_cols
        row_data.values.each_with_index do |cell_data, c|
          k = [r + 1, c + 1]
          @cells[k] = cell_data.formatted_value || ''
          @input_values[k] = extended_value_to_str(cell_data.user_entered_value)
          @numeric_values[k] =
              cell_data.effective_value && cell_data.effective_value.number_value ?
                  cell_data.effective_value.number_value.to_f : nil
        end
      end

      @modified.clear
    end

    def parse_cell_args(args)
      if args.size == 1 && args[0].is_a?(String)
        cell_name_to_row_col(args[0])
      elsif args.size == 2 && args[0].is_a?(Integer) && args[1].is_a?(Integer)
        if args[0] >= 1 && args[1] >= 1
          args
        else
          raise(
            ArgumentError,
            format(
              'Row/col must be >= 1 (1-origin), but are %d/%d',
              args[0], args[1]
            )
          )
        end
      else
        raise(
          ArgumentError,
          format(
            "Arguments must be either one String or two Integer's, but are %p",
            args
          )
        )
      end
    end

    def validate_cell_value(value)
      if value =~ XML_INVALID_CHAR_REGEXP
        raise(
          ArgumentError,
          format('Contains invalid character %p for XML 1.0: %p', $&, value)
        )
      end
    end

    def v4_range_object(top_row, left_col, num_rows, num_cols)
      Google::Apis::SheetsV4::GridRange.new(
        sheet_id: sheet_id,
        start_row_index: top_row - 1,
        start_column_index: left_col - 1,
        end_row_index: top_row + num_rows - 1,
        end_column_index: left_col + num_cols - 1
      )
    end

    def extended_value_to_str(extended_value)
      return '' if !extended_value
      value =
          extended_value.number_value ||
          extended_value.string_value ||
          extended_value.bool_value ||
          extended_value.formula_value
      value.to_s
    end
  end
end
