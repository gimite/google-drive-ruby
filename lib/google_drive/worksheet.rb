# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "set"

require "google_drive/util"
require "google_drive/error"
require "google_drive/table"
require "google_drive/list"


module GoogleDrive

    # A worksheet (i.e. a tab) in a spreadsheet.
    # Use GoogleDrive::Spreadsheet#worksheets to get GoogleDrive::Worksheet object.
    class Worksheet

        include(Util)

        def initialize(session, spreadsheet, cells_feed_url, title = nil, updated = nil) #:nodoc:
          
          @session = session
          @spreadsheet = spreadsheet
          @cells_feed_url = cells_feed_url
          @title = title
          @updated = updated

          @cells = nil
          @input_values = nil
          @numeric_values = nil
          @modified = Set.new()
          @list = nil
          
        end

        # URL of cell-based feed of the worksheet.
        attr_reader(:cells_feed_url)

        # URL of worksheet feed URL of the worksheet.
        def worksheet_feed_url
          # I don't know good way to get worksheet feed URL from cells feed URL.
          # Probably it would be cleaner to keep worksheet feed URL and get cells feed URL
          # from it.
          if !(@cells_feed_url =~
              %r{^https?://spreadsheets.google.com/feeds/cells/(.*)/(.*)/private/full((\?.*)?)$})
            raise(GoogleDrive::Error,
              "Cells feed URL is in unknown format: #{@cells_feed_url}")
          end
          return "https://spreadsheets.google.com/feeds/worksheets/#{$1}/private/full/#{$2}#{$3}"
        end

        # GoogleDrive::Spreadsheet which this worksheet belongs to.
        def spreadsheet
          if !@spreadsheet
            if !(@cells_feed_url =~
                %r{^https?://spreadsheets.google.com/feeds/cells/(.*)/(.*)/private/full(\?.*)?$})
              raise(GoogleDrive::Error,
                "Cells feed URL is in unknown format: #{@cells_feed_url}")
            end
            @spreadsheet = @session.spreadsheet_by_key($1)
          end
          return @spreadsheet
        end

        # Returns content of the cell as String. Arguments must be either
        # (row number, column number) or cell name. Top-left cell is [1, 1].
        #
        # e.g.
        #   worksheet[2, 1]  #=> "hoge"
        #   worksheet["A2"]  #=> "hoge"
        def [](*args)
          (row, col) = parse_cell_args(args)
          return self.cells[[row, col]] || ""
        end

        # Updates content of the cell.
        # Arguments in the bracket must be either (row number, column number) or cell name. 
        # Note that update is not sent to the server until you call save().
        # Top-left cell is [1, 1].
        #
        # e.g.
        #   worksheet[2, 1] = "hoge"
        #   worksheet["A2"] = "hoge"
        #   worksheet[1, 3] = "=A1+B1"
        def []=(*args)
          (row, col) = parse_cell_args(args[0...-1])
          value = args[-1].to_s()
          reload() if !@cells
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
            @num_rows = row if row > num_rows
            @num_cols = col if col > num_cols
          end
        end

        # Updates cells in a rectangle area by a two-dimensional Array.
        # +top_row+ and +left_col+ specifies the top-left corner of the area.
        #
        # e.g.
        #   worksheet.update_cells(2, 3, [["1", "2"], ["3", "4"]])
        def update_cells(top_row, left_col, darray)
          darray.each_with_index() do |array, y|
            array.each_with_index() do |value, x|
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
          reload() if !@cells
          return @input_values[[row, col]] || ""
        end

        # Returns the numeric value of the cell. Arguments must be either
        # (row number, column number) or cell name. Top-left cell is [1, 1].
        #
        # e.g.
        #   worksheet[1, 3]                #=> "3,0" # it depends on locale, currency...
        #   worksheet.numeric_value(1, 3)  #=> 3.0
        #
        # Returns nil if the cell is empty or contains non-number.
        #
        # If you modify the cell, its numeric_value is nil until you call save() and reload().
        #
        # For details, see:
        # https://developers.google.com/google-apps/spreadsheets/#working_with_cell-based_feeds
        def numeric_value(*args)
          (row, col) = parse_cell_args(args)
          reload() if !@cells
          return @numeric_values[[row, col]]
        end
        
        # Row number of the bottom-most non-empty row.
        def num_rows
          reload() if !@cells
          # Memoizes it because this can be bottle-neck.
          # https://github.com/gimite/google-drive-ruby/pull/49
          return @num_rows ||= @input_values.select(){ |(r, c), v| !v.empty? }.map(){ |(r, c), v| r }.max || 0
        end

        # Column number of the right-most non-empty column.
        def num_cols
          reload() if !@cells
          # Memoizes it because this can be bottle-neck.
          # https://github.com/gimite/google-drive-ruby/pull/49
          return @num_cols ||= @input_values.select(){ |(r, c), v| !v.empty? }.map(){ |(r, c), v| c }.max || 0
        end

        # Number of rows including empty rows.
        def max_rows
          reload() if !@cells
          return @max_rows
        end

        # Updates number of rows.
        # Note that update is not sent to the server until you call save().
        def max_rows=(rows)
          reload() if !@cells
          @max_rows = rows
          @meta_modified = true
        end

        # Number of columns including empty columns.
        def max_cols
          reload() if !@cells
          return @max_cols
        end

        # Updates number of columns.
        # Note that update is not sent to the server until you call save().
        def max_cols=(cols)
          reload() if !@cells
          @max_cols = cols
          @meta_modified = true
        end

        # Title of the worksheet (shown as tab label in Web interface).
        def title
          reload() if !@title
          return @title
        end

         # Date updated of the worksheet (shown as tab label in Web interface).
        def updated
          reload() if !@updated
          return @updated
        end

        # Updates title of the worksheet.
        # Note that update is not sent to the server until you call save().
        def title=(title)
          reload() if !@cells
          @title = title
          @meta_modified = true
        end

        def cells #:nodoc:
          reload() if !@cells
          return @cells
        end

        # An array of spreadsheet rows. Each row contains an array of
        # columns. Note that resulting array is 0-origin so:
        #
        #   worksheet.rows[0][0] == worksheet[1, 1]
        def rows(skip = 0)
          nc = self.num_cols
          result = ((1 + skip)..self.num_rows).map() do |row|
            (1..nc).map(){ |col| self[row, col] }.freeze()
          end
          return result.freeze()
        end

        # Reloads content of the worksheets from the server.
        # Note that changes you made by []= etc. is discarded if you haven't called save().
        def reload()
          
          doc = @session.request(:get, @cells_feed_url)
          @max_rows = doc.css("gs|rowCount").text.to_i()
          @max_cols = doc.css("gs|colCount").text.to_i()
          @title = doc.css("feed > title")[0].text

          @num_cols = nil
          @num_rows = nil

          @cells = {}
          @input_values = {}
          @numeric_values = {}
          doc.css("feed > entry").each() do |entry|
            cell = entry.css("gs|cell")[0]
            row = cell["row"].to_i()
            col = cell["col"].to_i()
            @cells[[row, col]] = cell.inner_text
            @input_values[[row, col]] = cell["inputValue"] || cell.inner_text
            numeric_value = cell["numericValue"]
            @numeric_values[[row, col]] = numeric_value ? numeric_value.to_f() : nil
          end
          @modified.clear()
          @meta_modified = false
          return true
          
        end

        # Saves your changes made by []=, etc. to the server.
        def save()
          
          sent = false

          if @meta_modified

            ws_doc = @session.request(:get, self.worksheet_feed_url)
            edit_url = ws_doc.css("link[rel='edit']")[0]["href"]
            xml = <<-"EOS"
              <entry xmlns='http://www.w3.org/2005/Atom'
                     xmlns:gs='http://schemas.google.com/spreadsheets/2006'>
                <title>#{h(self.title)}</title>
                <gs:rowCount>#{h(self.max_rows)}</gs:rowCount>
                <gs:colCount>#{h(self.max_cols)}</gs:colCount>
              </entry>
            EOS

            @session.request(
                :put, edit_url, :data => xml,
                :header => {"Content-Type" => "application/atom+xml;charset=utf-8", "If-Match" => "*"})

            @meta_modified = false
            sent = true

          end

          if !@modified.empty?

            # Gets id and edit URL for each cell.
            # Note that return-empty=true is required to get those info for empty cells.
            cell_entries = {}
            rows = @modified.map(){ |r, c| r }
            cols = @modified.map(){ |r, c| c }
            url = concat_url(@cells_feed_url,
                "?return-empty=true&min-row=#{rows.min}&max-row=#{rows.max}" +
                "&min-col=#{cols.min}&max-col=#{cols.max}")
            doc = @session.request(:get, url)

            for entry in doc.css("entry")
              row = entry.css("gs|cell")[0]["row"].to_i()
              col = entry.css("gs|cell")[0]["col"].to_i()
              cell_entries[[row, col]] = entry
            end

            # Updates cell values using batch operation.
            # If the data is large, we split it into multiple operations, otherwise batch may fail.
            @modified.each_slice(25) do |chunk|

              xml = <<-EOS
                <feed xmlns="http://www.w3.org/2005/Atom"
                      xmlns:batch="http://schemas.google.com/gdata/batch"
                      xmlns:gs="http://schemas.google.com/spreadsheets/2006">
                  <id>#{h(@cells_feed_url)}</id>
              EOS
              for row, col in chunk
                value = @cells[[row, col]]
                entry = cell_entries[[row, col]]
                id = entry.css("id").text
                edit_url = entry.css("link[rel='edit']")[0]["href"]
                xml << <<-EOS
                  <entry>
                    <batch:id>#{h(row)},#{h(col)}</batch:id>
                    <batch:operation type="update"/>
                    <id>#{h(id)}</id>
                    <link rel="edit" type="application/atom+xml"
                      href="#{h(edit_url)}"/>
                    <gs:cell row="#{h(row)}" col="#{h(col)}" inputValue="#{h(value)}"/>
                  </entry>
                EOS
              end
              xml << <<-"EOS"
                </feed>
              EOS

              batch_url = concat_url(@cells_feed_url, "/batch")
              result = @session.request(:post, batch_url, :data => xml, :header => {"Content-Type" => "application/atom+xml;charset=utf-8", "If-Match" => "*"})
              for entry in result.css("atom|entry")
                interrupted = entry.css("batch|interrupted")[0]
                if interrupted
                  raise(GoogleDrive::Error, "Update has failed: %s" %
                    interrupted["reason"])
                end
                if !(entry.css("batch|status").first["code"] =~ /^2/)
                  raise(GoogleDrive::Error, "Updating cell %s has failed: %s" %
                    [entry.css("atom|id").text, entry.css("batch|status")[0]["reason"]])
                end
              end

            end

            @modified.clear()
            sent = true

          end
          
          return sent
          
        end

        # Calls save() and reload().
        def synchronize()
          save()
          reload()
        end

        # Deletes this worksheet. Deletion takes effect right away without calling save().
        def delete()
          ws_doc = @session.request(:get, self.worksheet_feed_url)
          edit_url = ws_doc.css("link[rel='edit']")[0]["href"]
          @session.request(:delete, edit_url)
        end

        # Returns true if you have changes made by []= which haven't been saved.
        def dirty?
          return !@modified.empty?
        end

        # DEPRECATED: Table and Record feeds are deprecated and they will not be available after
        # March 2012.
        #
        # Creates table for the worksheet and returns GoogleDrive::Table.
        # See this document for details:
        # http://code.google.com/intl/en/apis/spreadsheets/docs/3.0/developers_guide_protocol.html#TableFeeds
        def add_table(table_title, summary, columns, options)
          
          warn(
              "DEPRECATED: Google Spreadsheet Table and Record feeds are deprecated and they " +
              "will not be available after March 2012.")
          default_options = { :header_row => 1, :num_rows => 0, :start_row => 2}
          options = default_options.merge(options)

          column_xml = ""
          columns.each() do |index, name|
            column_xml += "<gs:column index='#{h(index)}' name='#{h(name)}'/>\n"
          end

          xml = <<-"EOS"
            <entry xmlns="http://www.w3.org/2005/Atom"
              xmlns:gs="http://schemas.google.com/spreadsheets/2006">
              <title type='text'>#{h(table_title)}</title>
              <summary type='text'>#{h(summary)}</summary>
              <gs:worksheet name='#{h(self.title)}' />
              <gs:header row='#{options[:header_row]}' />
              <gs:data numRows='#{options[:num_rows]}' startRow='#{options[:start_row]}'>
                #{column_xml}
              </gs:data>
            </entry>
          EOS

          result = @session.request(:post, self.spreadsheet.tables_feed_url, :data => xml)
          return Table.new(@session, result)
          
        end

        # DEPRECATED: Table and Record feeds are deprecated and they will not be available after
        # March 2012.
        #
        # Returns list of tables for the workwheet.
        def tables
          warn(
              "DEPRECATED: Google Spreadsheet Table and Record feeds are deprecated and they " +
              "will not be available after March 2012.")
          return self.spreadsheet.tables.select(){ |t| t.worksheet_title == self.title }
        end

        # List feed URL of the worksheet.
        def list_feed_url
          # Gets the worksheets metafeed.
          entry = @session.request(:get, self.worksheet_feed_url)

          # Gets the URL of list-based feed for the given spreadsheet.
          return entry.css(
            "link[rel='http://schemas.google.com/spreadsheets/2006#listfeed']")[0]["href"]
        end
        
        # Provides access to cells using column names, assuming the first row contains column
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
          return @list ||= List.new(self)
        end
        
        # Returns a [row, col] pair for a cell name string.
        # e.g.
        #   worksheet.cell_name_to_row_col("C2")  #=> [2, 3]
        def cell_name_to_row_col(cell_name)
          if !cell_name.is_a?(String)
            raise(ArgumentError, "Cell name must be a string: %p" % cell_name)
          end
          if !(cell_name.upcase =~ /^([A-Z]+)(\d+)$/)
            raise(ArgumentError,
                "Cell name must be only letters followed by digits with no spaces in between: %p" %
                    cell_name)
          end
          col = 0
          $1.each_byte() do |b|
            # 0x41: "A"
            col = col * 26 + (b - 0x41 + 1)
          end
          row = $2.to_i()
          return [row, col]
        end

        def inspect
          fields = {:worksheet_feed_url => self.worksheet_feed_url}
          fields[:title] = @title if @title
          return "\#<%p %s>" % [self.class, fields.map(){ |k, v| "%s=%p" % [k, v] }.join(", ")]
        end
        
      private

        def parse_cell_args(args)
          if args.size == 1 && args[0].is_a?(String)
            return cell_name_to_row_col(args[0])
          elsif args.size == 2 && args[0].is_a?(Integer) && args[1].is_a?(Integer)
            if args[0] >= 1 && args[1] >= 1
              return args
            else
              raise(ArgumentError,
                  "Row/col must be >= 1 (1-origin), but are %d/%d" % [args[0], args[1]])
            end
          else
            raise(ArgumentError,
                "Arguments must be either one String or two Integer's, but are %p" % [args])
          end
        end
        
    end
    
end
