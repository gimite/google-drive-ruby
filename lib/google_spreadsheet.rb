# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "set"
require "net/https"
require "open-uri"
require "cgi"
require "rubygems"
require "hpricot"
Net::HTTP.version_1_2


module GoogleSpreadsheet
    
    # Authenticates with given +mail+ and +password+, and returns GoogleSpreadsheet::Session
    # if succeeds. Raises GoogleSpreadsheet::AuthenticationError if fails.
    # Google Apps account is supported.
    def self.login(mail, password)
      return Session.login(mail, password)
    end
    
    # Restores GoogleSpreadsheet::Session from +path+ and returns it.
    # If +path+ doesn't exist or authentication has failed, prompts mail and password on console,
    # authenticates with them, stores the session to +path+ and returns it.
    #
    # This method requires Ruby/Password library: http://www.caliban.org/ruby/ruby-password.shtml
    def self.saved_session(path = ENV["HOME"] + "/.ruby_google_spreadsheet.token")
      session = Session.new(File.exist?(path) ? File.read(path) : nil)
      session.on_auth_fail = proc() do
        require "password"
        $stderr.print("Mail: ")
        mail = $stdin.gets().chomp()
        password = Password.get()
        session.login(mail, password)
        open(path, "w", 0600){ |f| f.write(session.auth_token) }
        true
      end
      if !session.auth_token
        session.on_auth_fail.call()
      end
      return session
    end
    
    
    module Util #:nodoc:
      
      module_function
        
        def http_request(method, url, data, header = {})
          uri = URI.parse(url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          http.start() do
            path = uri.path + (uri.query ? "?#{uri.query}" : "")
            response = http.__send__(method, path, data, header)
            if !(response.code =~ /^2/)
              raise(GoogleSpreadsheet::Error, "Response code #{response.code} for POST #{url}: " +
                CGI.unescapeHTML(response.body))
            end
            return response.body
          end
        end
        
        def encode_query(params)
          return params.map(){ |k, v| uri_encode(k) + "=" + uri_encode(v) }.join("&")
        end
        
        def uri_encode(str)
          return URI.encode(str, /#{URI::UNSAFE}|&/n)
        end
        
        def h(str)
          return CGI.escapeHTML(str.to_s())
        end
        
    end
    
    
    # Raised when spreadsheets.google.com has returned error.
    class Error < RuntimeError
        
    end
    
    
    # Raised when GoogleSpreadsheet.login has failed.
    class AuthenticationError < GoogleSpreadsheet::Error
        
    end
    
    
    # Use GoogleSpreadsheet.login or GoogleSpreadsheet.saved_session to get
    # GoogleSpreadsheet::Session object.
    class Session
        
        include(Util)
        extend(Util)
        
        # The same as GoogleSpreadsheet.login.
        def self.login(mail, password)
          session = Session.new()
          session.login(mail, password)
          return session
        end
        
        # Creates session object with given authentication token.
        def initialize(auth_token = nil)
          @auth_token = auth_token
        end
        
        # Authenticates with given +mail+ and +password+, and updates current session object
        # if succeeds. Raises GoogleSpreadsheet::AuthenticationError if fails.
        # Google Apps account is supported.
        def login(mail, password)
          begin
            @auth_token = nil
            params = {
              "accountType" => "HOSTED_OR_GOOGLE",
              "Email" => mail,
              "Passwd" => password,
              "service" => "wise",
              "source" => "Gimite-RubyGoogleSpreadsheet-1.00",
            }
            response = http_request(:post,
              "https://www.google.com/accounts/ClientLogin", encode_query(params))
            @auth_token = response.slice(/^Auth=(.*)$/, 1)
          rescue GoogleSpreadsheet::Error => ex
            return true if @on_auth_fail && @on_auth_fail.call()
            raise(AuthenticationError, "authentication failed for #{mail}: #{ex.message}")
          end
        end
        
        # Authentication token.
        attr_accessor(:auth_token)
        
        # Proc or Method called when authentication has failed.
        # When this function returns +true+, it tries again.
        attr_accessor(:on_auth_fail)
        
        def get(url) #:nodoc:
          while true
            begin
              response = open(url, self.http_header){ |f| f.read() }
            rescue OpenURI::HTTPError => ex
              if ex.message =~ /^401/ && @on_auth_fail && @on_auth_fail.call()
                next
              end
              raise(ex.message =~ /^401/ ? AuthenticationError : GoogleSpreadsheet::Error,
                "Error #{ex.message} for GET #{url}: " + ex.io.read())
            end
            return Hpricot.XML(response)
          end
        end
        
        def post(url, data) #:nodoc:
          header = self.http_header.merge({"Content-Type" => "application/atom+xml"})
          response = http_request(:post, url, data, header)
          return Hpricot.XML(response)
        end
        
        def put(url, data) #:nodoc:
          header = self.http_header.merge({"Content-Type" => "application/atom+xml"})
          response = http_request(:put, url, data, header)
          return Hpricot.XML(response)
        end
        
        def http_header #:nodoc:
          return {"Authorization" => "GoogleLogin auth=#{@auth_token}"}
        end
        
        # Returns list of spreadsheets for the user as array of GoogleSpreadsheet::Spreadsheet.
        # You can specify query parameters described at
        # http://code.google.com/apis/spreadsheets/docs/2.0/reference.html#Parameters
        #
        # e.g.
        #   session.spreadsheets
        #   session.spreadsheets("title" => "hoge")
        def spreadsheets(params = {})
          query = encode_query(params)
          doc = get("http://spreadsheets.google.com/feeds/spreadsheets/private/full?#{query}")
          result = []
          for entry in doc.search("entry")
            title = entry.search("title").text
            url = entry.search(
              "link[@rel='http://schemas.google.com/spreadsheets/2006#worksheetsfeed']")[0]["href"]
            result.push(Spreadsheet.new(self, url, title))
          end
          return result
        end
        
        # Returns GoogleSpreadsheet::Spreadsheet with given +key+.
        #
        # e.g.
        #   # http://spreadsheets.google.com/ccc?key=pz7XtlQC-PYx-jrVMJErTcg&hl=ja
        #   session.spreadsheet_by_key("pz7XtlQC-PYx-jrVMJErTcg")
        def spreadsheet_by_key(key)
          url = "http://spreadsheets.google.com/feeds/worksheets/#{key}/private/full"
          return Spreadsheet.new(self, url)
        end
        
        # Returns GoogleSpreadsheet::Spreadsheet with given +url+. You must specify either of:
        # - URL of the page you open to access the spreadsheet in your browser
        # - URL of worksheet-based feed of the spreadseet
        #
        # e.g.
        #   session.spreadsheet_by_url(
        #     "http://spreadsheets.google.com/ccc?key=pz7XtlQC-PYx-jrVMJErTcg&hl=en")
        #   session.spreadsheet_by_url(
        #     "http://spreadsheets.google.com/feeds/worksheets/pz7XtlQC-PYx-jrVMJErTcg/private/full")
        def spreadsheet_by_url(url)
          # Tries to parse it as URL of human-readable spreadsheet.
          uri = URI.parse(url)
          if uri.host == "spreadsheets.google.com" && uri.path =~ /\/ccc$/
            if (uri.query || "").split(/&/).find(){ |s| s=~ /^key=(.*)$/ }
              return spreadsheet_by_key($1)
            end
          end
          # Assumes the URL is worksheets feed URL.
          return Spreadsheet.new(self, url)
        end
        
        # Returns GoogleSpreadsheet::Worksheet with given +url+.
        # You must specify URL of cell-based feed of the worksheet.
        #
        # e.g.
        #   session.worksheet_by_url(
        #     "http://spreadsheets.google.com/feeds/cells/pz7XtlQC-PYxNmbBVgyiNWg/od6/private/full")
        def worksheet_by_url(url)
          return Worksheet.new(self, url)
        end
        
    end
    
    
    # Use methods in GoogleSpreadsheet::Session to get GoogleSpreadsheet::Spreadsheet object.
    class Spreadsheet
        
        include(Util)
        
        def initialize(session, worksheets_feed_url, title = nil) #:nodoc:
          @session = session
          @worksheets_feed_url = worksheets_feed_url
          @title = title
        end
        
        # URL of worksheet-based feed of the spreadsheet.
        attr_reader(:worksheets_feed_url)
        
        # Title of the spreadsheet. So far only available if you get this object by
        # GoogleSpreadsheet::Session#spreadsheets.
        attr_reader(:title)
        
        # Returns worksheets of the spreadsheet as array of GoogleSpreadsheet::Worksheet.
        def worksheets
          doc = @session.get(@worksheets_feed_url)
          result = []
          for entry in doc.search("entry")
            title = entry.search("title").text
            url = entry.search(
              "link[@rel='http://schemas.google.com/spreadsheets/2006#cellsfeed']")[0]["href"]
            result.push(Worksheet.new(@session, url, title))
          end
          return result.freeze()
        end
        
        # Adds a new worksheet to the spreadsheet. Returns added GoogleSpreadsheet::Worksheet.
        def add_worksheet(title, max_rows = 100, max_cols = 20)
          xml = <<-"EOS"
            <entry xmlns='http://www.w3.org/2005/Atom'
                   xmlns:gs='http://schemas.google.com/spreadsheets/2006'>
              <title>#{h(title)}</title>
              <gs:rowCount>#{h(max_rows)}</gs:rowCount>
              <gs:colCount>#{h(max_cols)}</gs:colCount>
            </entry>
          EOS
          doc = @session.post(@worksheets_feed_url, xml)
          url = doc.search(
            "link[@rel='http://schemas.google.com/spreadsheets/2006#cellsfeed']")[0]["href"]
          return Worksheet.new(@session, url, title)
        end
        
    end
    
    
    # Use GoogleSpreadsheet::Spreadsheet#worksheets to get GoogleSpreadsheet::Worksheet object.
    class Worksheet
        
        include(Util)
        
        def initialize(session, cells_feed_url, title = nil) #:nodoc:
          @session = session
          @cells_feed_url = cells_feed_url
          @title = title
          @cells = nil
          @input_values = nil
          @modified = Set.new()
        end
        
        # URL of cell-based feed of the spreadsheet.
        attr_reader(:cells_feed_url)
        
        # Returns content of the cell as String. Top-left cell is [1, 1].
        def [](row, col)
          return self.cells[[row, col]] || ""
        end
        
        # Updates content of the cell.
        # Note that update is not sent to the server until you call save().
        # Top-left cell is [1, 1].
        #
        # e.g.
        #   worksheet[2, 1] = "hoge"
        #   worksheet[1, 3] = "=A1+B1"
        def []=(row, col, value)
          reload() if !@cells
          @cells[[row, col]] = value
          @input_values[[row, col]] = value
          @modified.add([row, col])
          self.max_rows = row if row > @max_rows
          self.max_cols = col if col > @max_cols
        end
        
        # Returns the value or the formula of the cell. Top-left cell is [1, 1].
        #
        # If user input "=A1+B1" to cell [1, 3], worksheet[1, 3] is "3" for example and
        # worksheet.input_value(1, 3) is "=RC[-2]+RC[-1]".
        def input_value(row, col)
          reload() if !@cells
          return @input_values[[row, col]] || ""
        end
        
        # Row number of the bottom-most non-empty row.
        def num_rows
          reload() if !@cells
          return @cells.keys.map(){ |r, c| r }.max || 0
        end
        
        # Column number of the right-most non-empty column.
        def num_cols
          reload() if !@cells
          return @cells.keys.map(){ |r, c| c }.max || 0
        end
        
        # Number of rows including empty rows.
        def max_rows
          reload() if !@cells
          return @max_rows
        end
        
        # Updates number of rows.
        # Note that update is not sent to the server until you call save().
        def max_rows=(rows)
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
          @max_cols = cols
          @meta_modified = true
        end
        
        # Title of the worksheet (shown as tab label in Web interface).
        def title
          reload() if !@title
          return @title
        end
        
        # Updates title of the worksheet.
        # Note that update is not sent to the server until you call save().
        def title=(title)
          @title = title
          @meta_modified = true
        end
        
        def cells #:nodoc:
          reload() if !@cells
          return @cells
        end
        
        # An array of spreadsheet rows. Each row contains an array of
        # columns. Note that resulting array is 0-origin so
        # worksheet.rows[0][0] == worksheet[1, 1].
        def rows
          nc = self.num_cols
          result = (1..self.num_rows).map() do |row|
            (1..nc).map(){ |col| self[row, col] }.freeze()
          end
          return result.freeze()
        end
        
        # Reloads content of the worksheets from the server.
        # Note that changes you made by []= is discarded if you haven't called save().
        def reload()
          doc = @session.get(@cells_feed_url)
          @max_rows = doc.search("gs:rowCount").text.to_i()
          @max_cols = doc.search("gs:colCount").text.to_i()
          @title = doc.search("title").text
          @cells = {}
          @input_values = {}
          for entry in doc.search("entry")
            cell = entry.search("gs:cell")[0]
            row = cell["row"].to_i()
            col = cell["col"].to_i()
            @cells[[row, col]] = cell.inner_text
            @input_values[[row, col]] = cell["inputValue"]
          end
          @modified.clear()
          @meta_modified = false
          return true
        end
        
        # Saves your changes made by []= to the server.
        def save()
          sent = false
          
          if @meta_modified
            
            # I don't know good way to get worksheet feed URL from cells feed URL.
            # Probably it would be cleaner to keep worksheet feed URL and get cells feed URL
            # from it.
            if !(@cells_feed_url =~
                %r{^http://spreadsheets.google.com/feeds/cells/(.*)/(.*)/private/full$})
              raise(GoogleSpreadsheet::Error,
                "cells feed URL is in unknown format: #{@cells_feed_url}")
            end
            ws_doc = @session.get(
              "http://spreadsheets.google.com/feeds/worksheets/#{$1}/private/full/#{$2}")
            edit_url = ws_doc.search("link[@rel='edit']")[0]["href"]
            xml = <<-"EOS"
              <entry xmlns='http://www.w3.org/2005/Atom'
                     xmlns:gs='http://schemas.google.com/spreadsheets/2006'>
                <title>#{h(@title)}</title>
                <gs:rowCount>#{h(@max_rows)}</gs:rowCount>
                <gs:colCount>#{h(@max_cols)}</gs:colCount>
              </entry>
            EOS
            @session.put(edit_url, xml)
            
            @meta_modified = false
            sent = true
            
          end
          
          if !@modified.empty?
            
            # Gets id and edit URL for each cell.
            # Note that return-empty=true is required to get those info for empty cells.
            cell_entries = {}
            rows = @modified.map(){ |r, c| r }
            cols = @modified.map(){ |r, c| c }
            url = "#{@cells_feed_url}?return-empty=true&min-row=#{rows.min}&max-row=#{rows.max}" +
              "&min-col=#{cols.min}&max-col=#{cols.max}"
            doc = @session.get(url)
            for entry in doc.search("entry")
              row = entry.search("gs:cell")[0]["row"].to_i()
              col = entry.search("gs:cell")[0]["col"].to_i()
              cell_entries[[row, col]] = entry
            end
            
            # Updates cell values using batch operation.
            xml = <<-"EOS"
              <feed xmlns="http://www.w3.org/2005/Atom"
                    xmlns:batch="http://schemas.google.com/gdata/batch"
                    xmlns:gs="http://schemas.google.com/spreadsheets/2006">
                <id>#{h(@cells_feed_url)}</id>
            EOS
            for row, col in @modified
              value = @cells[[row, col]]
              entry = cell_entries[[row, col]]
              id = entry.search("id").text
              edit_url = entry.search("link[@rel='edit']")[0]["href"]
              xml << <<-"EOS"
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
            result = @session.post("#{@cells_feed_url}/batch", xml)
            for entry in result.search("atom:entry")
              interrupted = entry.search("batch:interrupted")[0]
              if interrupted
                raise(GoogleSpreadsheet::Error, "Update has failed: %s" %
                  interrupted["reason"])
              end
              if !(entry.search("batch:status")[0]["code"] =~ /^2/)
                raise(GoogleSpreadsheet::Error, "Updating cell %s has failed: %s" %
                  [entry.search("atom:id").text, entry.search("batch:status")[0]["reason"]])
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
        
        # Returns true if you have changes made by []= which haven't been saved.
        def dirty?
          return !@modified.empty?
        end
        
    end
    
    
end
