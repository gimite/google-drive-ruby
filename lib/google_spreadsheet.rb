# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "enumerator"
require "set"
require "net/https"
require "open-uri"
require "cgi"
require "uri"
require "rubygems"
require "nokogiri"
require "oauth"
require "oauth2"
Net::HTTP.version_1_2

module GoogleSpreadsheet

    # Authenticates with given +mail+ and +password+, and returns GoogleSpreadsheet::Session
    # if succeeds. Raises GoogleSpreadsheet::AuthenticationError if fails.
    # Google Apps account is supported.
    #
    # +proxy+ can be nil or return value of Net::HTTP.Proxy. If +proxy+ is specified, all
    # HTTP access in the session uses the proxy. If +proxy+ is nil, it uses the proxy
    # specified by http_proxy environment variable if available. Otherwise it performs direct
    # access.
    def self.login(mail, password, proxy = nil)
      return Session.login(mail, password, proxy)
    end

    # Authenticates with given OAuth1 or OAuth2 token.
    #
    # OAuth2 code example:
    #
    #   client = OAuth2::Client.new(
    #       your_client_id, your_client_secret,
    #       :site => "https://accounts.google.com",
    #       :token_url => "/o/oauth2/token",
    #       :authorize_url => "/o/oauth2/auth")
    #   auth_url = client.auth_code.authorize_url(
    #       :redirect_uri => "http://example.com/",
    #       "scope" => "https://spreadsheets.google.com/feeds https://docs.google.com/feeds/")
    #   # Redirect the user to auth_url and get authorization code from redirect URL.
    #   auth_token = client.auth_code.get_token(
    #       authorization_code, :redirect_uri => "http://example.com/")
    #   session = GoogleSpreadsheet.login_with_oauth(auth_token)
    #
    # Or, from existing refresh token:
    #
    #   access_token = OAuth2::AccessToken.from_hash(client,
    #       {:refresh_token => refresh_token, :expires_at => expires_at})
    #   access_token = access_token.refresh!
    #   session = GoogleSpreadsheet.login_with_oauth(access_token)
    #
    # OAuth1 code example:
    #
    # 1) First generate OAuth consumer object with key and secret for your site by registering site with google
    #   @consumer = OAuth::Consumer.new( "key","secret", {:site=>"https://agree2"})
    # 2) Request token with OAuth
    #   @request_token = @consumer.get_request_token
    #   session[:request_token] = @request_token
    #   redirect_to @request_token.authorize_url
    # 3) Create an oauth access token
    #   @oauth_access_token = @request_token.get_access_token
    #   @access_token = OAuth::AccessToken.new(@consumer, @oauth_access_token.token, @oauth_access_token.secret)
    #
    # See these documents for details:
    #
    # - https://github.com/intridea/oauth2
    # - http://code.google.com/apis/accounts/docs/OAuth2.html
    # - http://oauth.rubyforge.org/
    # - http://code.google.com/apis/accounts/docs/OAuth.html
    def self.login_with_oauth(oauth_token)
      return Session.login_with_oauth(oauth_token)
    end

    # Restores session using return value of auth_tokens method of previous session.
    #
    # See GoogleSpreadsheet.login for description of parameter +proxy+.
    def self.restore_session(auth_tokens, proxy = nil)
      return Session.restore_session(auth_tokens, proxy)
    end
    
    # Restores GoogleSpreadsheet::Session from +path+ and returns it.
    # If +path+ doesn't exist or authentication has failed, prompts mail and password on console,
    # authenticates with them, stores the session to +path+ and returns it.
    #
    # See login for description of parameter +proxy+.
    #
    # This method requires Highline library: http://rubyforge.org/projects/highline/
    def self.saved_session(path = ENV["HOME"] + "/.ruby_google_spreadsheet.token", proxy = nil)
      tokens = {}
      if File.exist?(path)
        open(path) do |f|
          for auth in [:wise, :writely]
            line = f.gets()
            tokens[auth] = line && line.chomp()
          end
        end
      end
      session = Session.new(tokens, nil, proxy)
      session.on_auth_fail = proc() do
        begin
          require "highline"
        rescue LoadError
          raise(LoadError,
            "GoogleSpreadsheet.saved_session requires Highline library.\n" +
            "Run\n" +
            "  \$ sudo gem install highline\n" +
            "to install it.")
        end
        highline = HighLine.new()
        mail = highline.ask("Mail: ")
        password = highline.ask("Password: "){ |q| q.echo = false }
        session.login(mail, password)
        open(path, "w", 0600) do |f|
          f.puts(session.auth_token(:wise))
          f.puts(session.auth_token(:writely))
        end
        true
      end
      if !session.auth_token
        session.on_auth_fail.call()
      end
      return session
    end


    module Util #:nodoc:

      module_function

        def encode_query(params)
          return params.map(){ |k, v| CGI.escape(k) + "=" + CGI.escape(v) }.join("&")
        end
        
        def concat_url(url, piece)
          (url_base, url_query) = url.split(/\?/, 2)
          (piece_base, piece_query) = piece.split(/\?/, 2)
          result_query = [url_query, piece_query].select(){ |s| s && !s.empty? }.join("&")
          return url_base + piece_base + (result_query.empty? ? "" : "?#{result_query}")
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
    
    
    class ClientLoginFetcher #:nodoc:
        
        def initialize(auth_tokens, proxy)
          @auth_tokens = auth_tokens
          if proxy
            @proxy = proxy
          elsif ENV["http_proxy"] && !ENV["http_proxy"].empty?
            proxy_url = URI.parse(ENV["http_proxy"])
            @proxy = Net::HTTP.Proxy(proxy_url.host, proxy_url.port)
          else
            @proxy = Net::HTTP
          end
        end
        
        attr_accessor(:auth_tokens)
        
        def request_raw(method, url, data, extra_header, auth)
          uri = URI.parse(url)
          http = @proxy.new(uri.host, uri.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          http.start() do
            path = uri.path + (uri.query ? "?#{uri.query}" : "")
            header = auth_header(auth).merge(extra_header)
            if method == :delete || method == :get
              return http.__send__(method, path, header)
            else
              return http.__send__(method, path, data, header)
            end
          end
        end
        
      private
        
        def auth_header(auth)
          token = auth == :none ? nil : @auth_tokens[auth]
          if token
            return {"Authorization" => "GoogleLogin auth=#{token}"}
          else
            return {}
          end
        end

    end
    
    
    class OAuth1Fetcher #:nodoc:
        
        def initialize(oauth1_token)
          @oauth1_token = oauth1_token
        end
        
        def request_raw(method, url, data, extra_header, auth)
          if method == :delete || method == :get
            return @oauth1_token.__send__(method, url, extra_header)
          else
            return @oauth1_token.__send__(method, url, data, extra_header)
          end
        end
        
    end


    class OAuth2Fetcher #:nodoc:
        
        Response = Struct.new(:code, :body)
        
        def initialize(oauth2_token)
          @oauth2_token = oauth2_token
        end
        
        def request_raw(method, url, data, extra_header, auth)
          if method == :delete || method == :get
            raw_res = @oauth2_token.request(method, url, {:header => extra_header})
          else
            raw_res = @oauth2_token.request(method, url, {:header => extra_header, :body => data})
          end
          return Response.new(raw_res.status.to_s(), raw_res.body)
        end
        
    end


    # Use GoogleSpreadsheet.login or GoogleSpreadsheet.saved_session to get
    # GoogleSpreadsheet::Session object.
    class Session

        include(Util)
        extend(Util)

        # The same as GoogleSpreadsheet.login.
        def self.login(mail, password, proxy = nil)
          session = Session.new(nil, ClientLoginFetcher.new({}, proxy))
          session.login(mail, password)
          return session
        end

        # The same as GoogleSpreadsheet.login_with_oauth.
        def self.login_with_oauth(oauth_token)
          case oauth_token
            when OAuth::AccessToken
              fetcher = OAuth1Fetcher.new(oauth_token)
            when OAuth2::AccessToken
              fetcher = OAuth2Fetcher.new(oauth_token)
            else
              raise(GoogleSpreadsheet::Error,
                  "oauth_token is neither OAuth::Token nor OAuth2::Token: %p" % oauth_token)
          end
          return Session.new(nil, fetcher)
        end

        # The same as GoogleSpreadsheet.restore_session.
        def self.restore_session(auth_tokens, proxy = nil)
          return Session.new(auth_tokens, nil, proxy)
        end

        # DEPRECATED: Use GoogleSpreadsheet.restore_session instead.
        def initialize(auth_tokens = nil, fetcher = nil, proxy = nil)
          if fetcher
            @fetcher = fetcher
          else
            @fetcher = ClientLoginFetcher.new(auth_tokens || {}, proxy)
          end
        end

        # Authenticates with given +mail+ and +password+, and updates current session object
        # if succeeds. Raises GoogleSpreadsheet::AuthenticationError if fails.
        # Google Apps account is supported.
        def login(mail, password)
          if !@fetcher.is_a?(ClientLoginFetcher)
            raise(GoogleSpreadsheet::Error,
                "Cannot call login for session created by login_with_oauth or login_with_oauth2.")
          end
          begin
            @fetcher.auth_tokens = {
              :wise => authenticate(mail, password, :wise),
              :writely => authenticate(mail, password, :writely),
            }
          rescue GoogleSpreadsheet::Error => ex
            return true if @on_auth_fail && @on_auth_fail.call()
            raise(AuthenticationError, "authentication failed for #{mail}: #{ex.message}")
          end
        end

        # Authentication tokens.
        def auth_tokens
          if !@fetcher.is_a?(ClientLoginFetcher)
            raise(GoogleSpreadsheet::Error,
                "Cannot call auth_tokens for session created by " +
                "login_with_oauth or login_with_oauth2.")
          end
          return @fetcher.auth_tokens
        end

        # Authentication token.
        def auth_token(auth = :wise)
          return self.auth_tokens[auth]
        end

        # Proc or Method called when authentication has failed.
        # When this function returns +true+, it tries again.
        attr_accessor :on_auth_fail

        # Returns list of spreadsheets for the user as array of GoogleSpreadsheet::Spreadsheet.
        # You can specify query parameters described at
        # http://code.google.com/apis/spreadsheets/docs/2.0/reference.html#Parameters
        #
        # e.g.
        #   session.spreadsheets
        #   session.spreadsheets("title" => "hoge")
        def spreadsheets(params = {})
          query = encode_query(params)
          doc = request(:get, "https://spreadsheets.google.com/feeds/spreadsheets/private/full?#{query}")
          result = []
          doc.css("feed > entry").each() do |entry|
            title = entry.css("title").text
            url = entry.css(
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
          url = "https://spreadsheets.google.com/feeds/worksheets/#{key}/private/full"
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
        #     "https://spreadsheets.google.com/feeds/worksheets/pz7XtlQC-PYx-jrVMJErTcg/private/full")
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
          return Worksheet.new(self, nil, url)
        end

        # Returns GoogleSpreadsheet::Collection with given +url+.
        # You must specify URL of collection (folder) feed.
        #
        # e.g.
        #   session.collection_by_url(
        #     "http://docs.google.com/feeds/default/private/full/folder%3A" +
        #     "0B9GfDpQ2pBVUODNmOGE0NjIzMWU3ZC00NmUyLTk5NzEtYaFkZjY1MjAyxjMc")
        def collection_by_url(url)
          return Collection.new(self, url)
        end

        # Creates new spreadsheet and returns the new GoogleSpreadsheet::Spreadsheet.
        #
        # e.g.
        #   session.create_spreadsheet("My new sheet")
        def create_spreadsheet(
            title = "Untitled",
            feed_url = "https://docs.google.com/feeds/documents/private/full")
          xml = <<-"EOS"
            <atom:entry xmlns:atom="http://www.w3.org/2005/Atom" xmlns:docs="http://schemas.google.com/docs/2007">
              <atom:category scheme="http://schemas.google.com/g/2005#kind"
                  term="http://schemas.google.com/docs/2007#spreadsheet" label="spreadsheet"/>
              <atom:title>#{h(title)}</atom:title>
            </atom:entry>
          EOS

          doc = request(:post, feed_url, :data => xml, :auth => :writely)
          ss_url = doc.css(
            "link[@rel='http://schemas.google.com/spreadsheets/2006#worksheetsfeed']").first['href']
          return Spreadsheet.new(self, ss_url, title)
        end

        def request(method, url, params = {}) #:nodoc:
          # Always uses HTTPS.
          url = url.gsub(%r{^http://}, "https://")
          data = params[:data]
          auth = params[:auth] || :wise
          if params[:header]
            extra_header = params[:header]
          elsif data
            extra_header = {"Content-Type" => "application/atom+xml"}
          else
            extra_header = {}
          end
          response_type = params[:response_type] || :xml

          while true
            response = @fetcher.request_raw(method, url, data, extra_header, auth)
            if response.code == "401" && @on_auth_fail && @on_auth_fail.call()
              next
            end
            if !(response.code =~ /^2/)
              raise(
                response.code == "401" ? AuthenticationError : GoogleSpreadsheet::Error,
                "Response code #{response.code} for #{method} #{url}: " +
                CGI.unescapeHTML(response.body))
            end
            return convert_response(response, response_type)
          end
        end

      private

        def convert_response(response, response_type)
          case response_type
            when :xml
              return Nokogiri.XML(response.body)
            when :raw
              return response.body
            else
              raise("unknown params[:response_type]: %s" % response_type)
          end
        end

        def authenticate(mail, password, auth)
          params = {
            "accountType" => "HOSTED_OR_GOOGLE",
            "Email" => mail,
            "Passwd" => password,
            "service" => auth.to_s(),
            "source" => "Gimite-RubyGoogleSpreadsheet-1.00",
          }
          header = {"Content-Type" => "application/x-www-form-urlencoded"}
          response = request(:post,
            "https://www.google.com/accounts/ClientLogin",
            :data => encode_query(params), :auth => :none, :header => header, :response_type => :raw)
          return response.slice(/^Auth=(.*)$/, 1)
        end

    end


    # Use methods in GoogleSpreadsheet::Session to get GoogleSpreadsheet::Spreadsheet object.
    class Spreadsheet

        include(Util)
        
        SUPPORTED_EXPORT_FORMAT = Set.new(["xls", "csv", "pdf", "ods", "tsv", "html"])

        def initialize(session, worksheets_feed_url, title = nil) #:nodoc:
          @session = session
          @worksheets_feed_url = worksheets_feed_url
          @title = title
        end

        # URL of worksheet-based feed of the spreadsheet.
        attr_reader(:worksheets_feed_url)

        # Title of the spreadsheet.
        #
        # Set params[:reload] to true to force reloading the title.
        def title(params = {})
          if !@title || params[:reload]
            @title = spreadsheet_feed_entry(params).css("title").text
          end
          return @title
        end

        # Key of the spreadsheet.
        def key
          if !(@worksheets_feed_url =~
              %r{^https?://spreadsheets.google.com/feeds/worksheets/(.*)/private/.*$})
            raise(GoogleSpreadsheet::Error,
              "worksheets feed URL is in unknown format: #{@worksheets_feed_url}")
          end
          return $1
        end
        
        # Spreadsheet feed URL of the spreadsheet.
        def spreadsheet_feed_url
          return "https://spreadsheets.google.com/feeds/spreadsheets/private/full/#{self.key}"
        end
        
        # URL which you can open the spreadsheet in a Web browser with.
        #
        # e.g. "http://spreadsheets.google.com/ccc?key=pz7XtlQC-PYx-jrVMJErTcg"
        def human_url
          # Uses Document feed because Spreadsheet feed returns wrong URL for Apps account.
          return self.document_feed_entry.css("link[@rel='alternate']").first["href"]
        end

        # DEPRECATED: Table and Record feeds are deprecated and they will not be available after
        # March 2012.
        #
        # Tables feed URL of the spreadsheet.
        def tables_feed_url
          warn(
              "DEPRECATED: Google Spreadsheet Table and Record feeds are deprecated and they will " +
              "not be available after March 2012.")
          return "https://spreadsheets.google.com/feeds/#{self.key}/tables"
        end

        # URL of feed used in document list feed API.
        def document_feed_url
          return "https://docs.google.com/feeds/documents/private/full/spreadsheet%3A#{self.key}"
        end

        # <entry> element of spreadsheet feed as Nokogiri::XML::Element.
        #
        # Set params[:reload] to true to force reloading the feed.
        def spreadsheet_feed_entry(params = {})
          if !@spreadsheet_feed_entry || params[:reload]
            @spreadsheet_feed_entry =
                @session.request(:get, self.spreadsheet_feed_url).css("entry").first
          end
          return @spreadsheet_feed_entry
        end
        
        # <entry> element of document list feed as Nokogiri::XML::Element.
        #
        # Set params[:reload] to true to force reloading the feed.
        def document_feed_entry(params = {})
          if !@document_feed_entry || params[:reload]
            @document_feed_entry =
                @session.request(:get, self.document_feed_url, :auth => :writely).css("entry").first
          end
          return @document_feed_entry
        end
        
        # Creates copy of this spreadsheet with the given title.
        def duplicate(new_title = nil)
          new_title ||= (self.title ? "Copy of " + self.title : "Untitled")
          post_url = "https://docs.google.com/feeds/default/private/full/"
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml"}
          xml = <<-"EOS"
            <entry xmlns='http://www.w3.org/2005/Atom'>
              <id>#{h(self.document_feed_url)}</id>
              <title>#{h(new_title)}</title>
            </entry>
          EOS
          doc = @session.request(:post, post_url, :data => xml, :header => header, :auth => :writely)
          ss_url = doc.css(
              "link[@rel='http://schemas.google.com/spreadsheets/2006#worksheetsfeed']").first["href"]
          return Spreadsheet.new(@session, ss_url, new_title)
        end

        # If +permanent+ is +false+, moves the spreadsheet to the trash.
        # If +permanent+ is +true+, deletes the spreadsheet permanently.
        def delete(permanent = false)
          @session.request(:delete,
            self.document_feed_url + (permanent ? "?delete=true" : ""),
            :auth => :writely, :header => {"If-Match" => "*"})
        end

        # Renames title of the spreadsheet.
        def rename(title)
          doc = @session.request(:get, self.document_feed_url, :auth => :writely)
          edit_url = doc.css("link[@rel='edit']").first["href"]
          xml = <<-"EOS"
            <atom:entry
                xmlns:atom="http://www.w3.org/2005/Atom"
                xmlns:docs="http://schemas.google.com/docs/2007">
              <atom:category
                scheme="http://schemas.google.com/g/2005#kind"
                term="http://schemas.google.com/docs/2007#spreadsheet" label="spreadsheet"/>
              <atom:title>#{h(title)}</atom:title>
            </atom:entry>
          EOS

          @session.request(:put, edit_url, :data => xml, :auth => :writely)
        end
        
        alias title= rename
        
        # Exports the spreadsheet in +format+ and returns it as String.
        #
        # +format+ can be either "xls", "csv", "pdf", "ods", "tsv" or "html".
        # In format such as "csv", only the worksheet specified with +worksheet_index+ is exported.
        def export_as_string(format, worksheet_index = nil)
          gid_param = worksheet_index ? "&gid=#{worksheet_index}" : ""
          url =
              "https://spreadsheets.google.com/feeds/download/spreadsheets/Export" +
              "?key=#{key}&exportFormat=#{format}#{gid_param}"
          return @session.request(:get, url, :response_type => :raw)
        end
        
        # Exports the spreadsheet in +format+ as a local file.
        #
        # +format+ can be either "xls", "csv", "pdf", "ods", "tsv" or "html".
        # If +format+ is nil, it is guessed from the file name.
        # In format such as "csv", only the worksheet specified with +worksheet_index+ is exported.
        def export_as_file(local_path, format = nil, worksheet_index = nil)
          if !format
            format = File.extname(local_path).gsub(/^\./, "")
            if !SUPPORTED_EXPORT_FORMAT.include?(format)
              raise(ArgumentError,
                  ("Cannot guess format from the file name: %s\n" +
                   "Specify format argument explicitly") %
                  local_path)
            end
          end
          open(local_path, "wb") do |f|
            f.write(export_as_string(format, worksheet_index))
          end
        end
        
        # Returns worksheets of the spreadsheet as array of GoogleSpreadsheet::Worksheet.
        def worksheets
          doc = @session.request(:get, @worksheets_feed_url)
          result = []
          doc.css('entry').each() do |entry|
            title = entry.css('title').text
            url = entry.css(
              "link[@rel='http://schemas.google.com/spreadsheets/2006#cellsfeed']").first['href']
            result.push(Worksheet.new(@session, self, url, title))
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
          doc = @session.request(:post, @worksheets_feed_url, :data => xml)
          url = doc.css(
            "link[@rel='http://schemas.google.com/spreadsheets/2006#cellsfeed']").first['href']
          return Worksheet.new(@session, self, url, title)
        end

        # DEPRECATED: Table and Record feeds are deprecated and they will not be available after
        # March 2012.
        #
        # Returns list of tables in the spreadsheet.
        def tables
          warn(
              "DEPRECATED: Google Spreadsheet Table and Record feeds are deprecated and they will " +
              "not be available after March 2012.")
          doc = @session.request(:get, self.tables_feed_url)
          return doc.css('entry').map(){ |e| Table.new(@session, e) }.freeze()
        end

    end
    
    # Use GoogleSpreadsheet::Session#collection_by_url to get GoogleSpreadsheet::Collection object.
    class Collection

        include(Util)
        
        def initialize(session, collection_feed_url) #:nodoc:
          @session = session
          @collection_feed_url = collection_feed_url
        end
        
        # Adds the given GoogleSpreadsheet::Spreadsheet to the collection.
        def add(spreadsheet)
          contents_url = concat_url(@collection_feed_url, "/contents")
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml"}
          xml = <<-"EOS"
            <entry xmlns="http://www.w3.org/2005/Atom">
              <id>#{h(spreadsheet.document_feed_url)}</id>
            </entry>
          EOS
          @session.request(
              :post, contents_url, :data => xml, :header => header, :auth => :writely)
          return nil
        end
        
        # TODO Add other operations.

    end
    
    # DEPRECATED: Table and Record feeds are deprecated and they will not be available after
    # March 2012.
    #
    # Use GoogleSpreadsheet::Worksheet#add_table to create table.
    # Use GoogleSpreadsheet::Worksheet#tables to get GoogleSpreadsheet::Table objects.
    class Table

        include(Util)

        def initialize(session, entry) #:nodoc:
          @columns = {}
          @worksheet_title = entry.css('gs|worksheet').first['name']
          @records_url = entry.css("content")[0]["src"]
          @edit_url = entry.css("link[@rel='edit']")[0]['href']
          @session = session
        end

        # Title of the worksheet the table belongs to.
        attr_reader(:worksheet_title)

        # Adds a record.
        def add_record(values)
          fields = ""
          values.each() do |name, value|
            fields += "<gs:field name='#{h(name)}'>#{h(value)}</gs:field>"
          end
          xml =<<-EOS
            <entry
                xmlns="http://www.w3.org/2005/Atom"
                xmlns:gs="http://schemas.google.com/spreadsheets/2006">
              #{fields}
            </entry>
          EOS
          @session.request(:post, @records_url, :data => xml)
        end

        # Returns records in the table.
        def records
          doc = @session.request(:get, @records_url)
          return doc.css('entry').map(){ |e| Record.new(@session, e) }
        end

        # Deletes this table. Deletion takes effect right away without calling save().
        def delete
          @session.request(:delete, @edit_url, :header => {"If-Match" => "*"})
        end

    end

    # DEPRECATED: Table and Record feeds are deprecated and they will not be available after
    # March 2012.
    #
    # Use GoogleSpreadsheet::Table#records to get GoogleSpreadsheet::Record objects.
    class Record < Hash
        include(Util)

        def initialize(session, entry) #:nodoc:
          @session = session
          entry.css('gs|field').each() do |field|
            self[field["name"]] = field.inner_text
          end
        end

        def inspect #:nodoc:
          content = self.map(){ |k, v| "%p => %p" % [k, v] }.join(", ")
          return "\#<%p:{%s}>" % [self.class, content]
        end

    end

    # Use GoogleSpreadsheet::Spreadsheet#worksheets to get GoogleSpreadsheet::Worksheet object.
    class Worksheet

        include(Util)

        def initialize(session, spreadsheet, cells_feed_url, title = nil) #:nodoc:
          @session = session
          @spreadsheet = spreadsheet
          @cells_feed_url = cells_feed_url
          @title = title

          @cells = nil
          @input_values = nil
          @modified = Set.new()
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
            raise(GoogleSpreadsheet::Error,
              "cells feed URL is in unknown format: #{@cells_feed_url}")
          end
          return "https://spreadsheets.google.com/feeds/worksheets/#{$1}/private/full/#{$2}#{$3}"
        end

        # GoogleSpreadsheet::Spreadsheet which this worksheet belongs to.
        def spreadsheet
          if !@spreadsheet
            if !(@cells_feed_url =~
                %r{^https?://spreadsheets.google.com/feeds/cells/(.*)/(.*)/private/full(\?.*)?$})
              raise(GoogleSpreadsheet::Error,
                "cells feed URL is in unknown format: #{@cells_feed_url}")
            end
            @spreadsheet = @session.spreadsheet_by_key($1)
          end
          return @spreadsheet
        end

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
        # columns. Note that resulting array is 0-origin so
        # worksheet.rows[0][0] == worksheet[1, 1].
        def rows(skip = 0)
          nc = self.num_cols
          result = ((1 + skip)..self.num_rows).map() do |row|
            (1..nc).map(){ |col| self[row, col] }.freeze()
          end
          return result.freeze()
        end

        # Reloads content of the worksheets from the server.
        # Note that changes you made by []= is discarded if you haven't called save().
        def reload()
          doc = @session.request(:get, @cells_feed_url)
          @max_rows = doc.css('gs|rowCount').text.to_i
          @max_cols = doc.css('gs|colCount').text.to_i
          @title = doc.css('feed > title')[0].text

          @cells = {}
          @input_values = {}
          doc.css('feed > entry').each() do |entry|
            cell = entry.css('gs|cell').first
            row = cell["row"].to_i()
            col = cell["col"].to_i()
            @cells[[row, col]] = cell.inner_text
            @input_values[[row, col]] = cell["inputValue"]

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
            edit_url = ws_doc.css("link[@rel='edit']").first['href']
            xml = <<-"EOS"
              <entry xmlns='http://www.w3.org/2005/Atom'
                     xmlns:gs='http://schemas.google.com/spreadsheets/2006'>
                <title>#{h(self.title)}</title>
                <gs:rowCount>#{h(self.max_rows)}</gs:rowCount>
                <gs:colCount>#{h(self.max_cols)}</gs:colCount>
              </entry>
            EOS

            @session.request(:put, edit_url, :data => xml)

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

            doc.css('entry').each() do |entry|
              row = entry.css('gs|cell').first['row'].to_i
              col = entry.css('gs|cell').first['col'].to_i
              cell_entries[[row, col]] = entry
            end

            # Updates cell values using batch operation.
            # If the data is large, we split it into multiple operations, otherwise batch may fail.
            @modified.each_slice(250) do |chunk|

              xml = <<-EOS
                <feed xmlns="http://www.w3.org/2005/Atom"
                      xmlns:batch="http://schemas.google.com/gdata/batch"
                      xmlns:gs="http://schemas.google.com/spreadsheets/2006">
                  <id>#{h(@cells_feed_url)}</id>
              EOS
              for row, col in chunk
                value = @cells[[row, col]]
                entry = cell_entries[[row, col]]
                id = entry.css('id').text
                edit_url = entry.css("link[@rel='edit']").first['href']
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
              result = @session.request(:post, batch_url, :data => xml)
              result.css('atom|entry').each() do |entry|
                interrupted = entry.css('batch|interrupted').first
                if interrupted
                  raise(GoogleSpreadsheet::Error, "Update has failed: %s" %
                    interrupted["reason"])
                end
                if !(entry.css('batch|status').first['code'] =~ /^2/)
                  raise(GoogleSpreadsheet::Error, "Updating cell %s has failed: %s" %
                    [entry.css('atom|id').text, entry.css('batch|status').first['reason']])
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
          edit_url = ws_doc.css("link[@rel='edit']").first['href']
          @session.request(:delete, edit_url)
        end

        # Returns true if you have changes made by []= which haven't been saved.
        def dirty?
          return !@modified.empty?
        end

        # DEPRECATED: Table and Record feeds are deprecated and they will not be available after
        # March 2012.
        #
        # Creates table for the worksheet and returns GoogleSpreadsheet::Table.
        # See this document for details:
        # http://code.google.com/intl/en/apis/spreadsheets/docs/3.0/developers_guide_protocol.html#TableFeeds
        def add_table(table_title, summary, columns, options)
          warn(
              "DEPRECATED: Google Spreadsheet Table and Record feeds are deprecated and they will " +
              "not be available after March 2012.")
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

        # Returns list of tables for the workwheet.
        def tables
          return self.spreadsheet.tables.select(){ |t| t.worksheet_title == self.title }
        end

        # List feed URL of the worksheet.
        def list_feed_url
          # Gets the worksheets metafeed.
          entry = @session.request(:get, self.worksheet_feed_url)

          # Gets the URL of list-based feed for the given spreadsheet.
          return entry.css(
            "link[@rel='http://schemas.google.com/spreadsheets/2006#listfeed']").first['href']
        end

    end


end
