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

    # @api private
    # A regexp which matches an invalid character in XML 1.0:
    # https://en.wikipedia.org/wiki/Valid_characters_in_XML#XML_1.0
    XML_INVAILD_CHAR_REGEXP =
      /[^\u0009\u000a\u000d\u0020-\ud7ff\ue000-\ufffd\u{10000}-\u{10ffff}]/

    # @api private
    def initialize(session, spreadsheet, worksheet_feed_entry)
      @session = session
      @spreadsheet = spreadsheet
      set_worksheet_feed_entry(worksheet_feed_entry)

      @cells = nil
      @input_values = nil
      @numeric_values = nil
      @modified = Set.new
      @list = nil
    end

    # Nokogiri::XML::Element object of the <entry> element in a worksheets feed.
    attr_reader(:worksheet_feed_entry)

    # Title of the worksheet (shown as tab label in Web interface).
    attr_reader(:title)

    # Time object which represents the time the worksheet was last updated.
    attr_reader(:updated)

    # URL of cell-based feed of the worksheet.
    def cells_feed_url
      @worksheet_feed_entry.css(
        "link[rel='http://schemas.google.com/spreadsheets/2006#cellsfeed']"
      )[0]['href']
    end

    # URL of worksheet feed URL of the worksheet.
    def worksheet_feed_url
      @worksheet_feed_entry.css("link[rel='self']")[0]['href']
    end

    # URL to export the worksheet as CSV.
    def csv_export_url
      @worksheet_feed_entry.css(
        "link[rel='http://schemas.google.com/spreadsheets/2006#exportcsv']"
      )[0]['href']
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

    # gid of the worksheet.
    def gid
      # A bit tricky but couldn't find a better way.
      CGI.parse(URI.parse(csv_export_url).query)['gid'].last
    end

    # URL to view/edit the worksheet in a Web browser.
    def human_url
      format("%s\#gid=%s", spreadsheet.human_url, gid)
    end

    # GoogleDrive::Spreadsheet which this worksheet belongs to.
    def spreadsheet
      unless @spreadsheet
        unless worksheet_feed_url =~
               %r{https?://spreadsheets\.google\.com/feeds/worksheets/(.*)/(.*)$}
          raise(GoogleDrive::Error,
                'Worksheet feed URL is in unknown format: ' \
                "#{worksheet_feed_url}")
        end
        @spreadsheet = @session.file_by_id(Regexp.last_match(1))
      end
      @spreadsheet
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
      set_worksheet_feed_entry(@session.request(:get, worksheet_feed_url).root)
      reload_cells
      true
    end

    # Saves your changes made by []=, etc. to the server.
    def save
      sent = false

      if @meta_modified

        edit_url = @worksheet_feed_entry.css("link[rel='edit']")[0]['href']
        xml = <<-"EOS"
              <entry xmlns='http://www.w3.org/2005/Atom'
                     xmlns:gs='http://schemas.google.com/spreadsheets/2006'>
                <title>#{h(title)}</title>
                <gs:rowCount>#{h(max_rows)}</gs:rowCount>
                <gs:colCount>#{h(max_cols)}</gs:colCount>
              </entry>
            EOS

        result = @session.request(
          :put,
          edit_url,
          data: xml,
          header: {
            'Content-Type' => 'application/atom+xml;charset=utf-8',
            'If-Match' => '*'
          }
        )
        set_worksheet_feed_entry(result.root)

        sent = true
      end

      unless @modified.empty?
        # Gets id and edit URL for each cell.
        # Note that return-empty=true is required to get those info for empty cells.
        cell_entries = {}
        rows = @modified.map { |r, _c| r }
        cols = @modified.map { |_r, c| c }
        url = concat_url(
          cells_feed_url,
          "?return-empty=true&min-row=#{rows.min}&max-row=#{rows.max}" \
          "&min-col=#{cols.min}&max-col=#{cols.max}"
        )
        doc = @session.request(:get, url)

        doc.css('entry').each do |entry|
          row                      = entry.css('gs|cell')[0]['row'].to_i
          col                      = entry.css('gs|cell')[0]['col'].to_i
          cell_entries[[row, col]] = entry
        end

        xml = <<-EOS
              <feed xmlns="http://www.w3.org/2005/Atom"
                    xmlns:batch="http://schemas.google.com/gdata/batch"
                    xmlns:gs="http://schemas.google.com/spreadsheets/2006">
                <id>#{h(cells_feed_url)}</id>
            EOS
        @modified.each do |row, col|
          value     = @cells[[row, col]]
          entry     = cell_entries[[row, col]]
          id        = entry.css('id').text
          edit_link = entry.css("link[rel='edit']")[0]
          unless edit_link
            raise(
              GoogleDrive::Error,
              format(
                "The user doesn't have write permission to the spreadsheet: %p",
                spreadsheet
              )
            )
          end
          edit_url = edit_link['href']
          xml << <<-EOS
                <entry>
                  <batch:id>#{h(row)},#{h(col)}</batch:id>
                  <batch:operation type="update"/>
                  <id>#{h(id)}</id>
                  <link
                    rel="edit"
                    type="application/atom+xml"
                    href="#{h(edit_url)}"/>
                  <gs:cell
                    row="#{h(row)}"
                    col="#{h(col)}"
                    inputValue="#{h(value)}"/>
                </entry>
          EOS
        end
        xml << <<-"EOS"
          </feed>
        EOS

        batch_url = concat_url(cells_feed_url, '/batch')
        result = @session.request(
          :post,
          batch_url,
          data: xml,
          header: {
            'Content-Type' => 'application/atom+xml;charset=utf-8',
            'If-Match' => '*'
          }
        )
        result.css('entry').each do |entry|
          interrupted = entry.css('batch|interrupted')[0]
          if interrupted
            raise(
              GoogleDrive::Error,
              format('Update has failed: %s', interrupted['reason'])
            )
          end
          next if entry.css('batch|status').first['code'] =~ /^2/
          raise(
            GoogleDrive::Error,
            format(
              'Updating cell %s has failed: %s',
              entry.css('id').text, entry.css('batch|status')[0]['reason']
            )
          )
        end

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
      ws_doc = @session.request(:get, worksheet_feed_url)
      edit_url = ws_doc.css("link[rel='edit']")[0]['href']
      @session.request(:delete, edit_url)
    end

    # Returns true if you have changes made by []= which haven't been saved.
    def dirty?
      !@modified.empty?
    end

    # List feed URL of the worksheet.
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
      fields = { worksheet_feed_url: worksheet_feed_url }
      fields[:title] = @title if @title
      format(
        "\#<%p %s>",
        self.class,
        fields.map { |k, v| format('%s=%p', k, v) }.join(', ')
      )
    end

    private

    def set_worksheet_feed_entry(entry)
      @worksheet_feed_entry = entry
      @title = entry.css('title').text
      set_max_values(entry)
      @updated = Time.parse(entry.css('updated').text)
      @meta_modified = false
    end

    def set_max_values(entry)
      @max_rows = entry.css('gs|rowCount').text.to_i
      @max_cols = entry.css('gs|colCount').text.to_i
    end

    def reload_cells
      doc = @session.request(:get, cells_feed_url)

      @num_cols = nil
      @num_rows = nil

      @cells = {}
      @input_values = {}
      @numeric_values = {}
      doc.css('feed > entry').each do |entry|
        cell = entry.css('gs|cell')[0]
        row = cell['row'].to_i
        col = cell['col'].to_i
        @cells[[row, col]] = cell.inner_text
        @input_values[[row, col]] = cell['inputValue'] || cell.inner_text
        numeric_value = cell['numericValue']
        @numeric_values[[row, col]] = numeric_value ? numeric_value.to_f : nil
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
      if value =~ XML_INVAILD_CHAR_REGEXP
        raise(
          ArgumentError,
          format('Contains invalid character %p for XML 1.0: %p', $&, value)
        )
      end
    end
  end
end
