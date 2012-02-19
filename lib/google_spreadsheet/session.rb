# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "cgi"

require "rubygems"
require "nokogiri"

require "google_spreadsheet/util"
require "google_spreadsheet/client_login_fetcher"
require "google_spreadsheet/oauth1_fetcher"
require "google_spreadsheet/oauth2_fetcher"
require "google_spreadsheet/error"
require "google_spreadsheet/authentication_error"
require "google_spreadsheet/spreadsheet"
require "google_spreadsheet/worksheet"
require "google_spreadsheet/collection"


module GoogleSpreadsheet

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
                "Cannot call login for session created by login_with_oauth.")
          end
          begin
            @fetcher.auth_tokens = {
              :wise => authenticate(mail, password, :wise),
              :writely => authenticate(mail, password, :writely),
            }
          rescue GoogleSpreadsheet::Error => ex
            return true if @on_auth_fail && @on_auth_fail.call()
            raise(AuthenticationError, "Authentication failed for #{mail}: #{ex.message}")
          end
        end

        # Authentication tokens.
        def auth_tokens
          if !@fetcher.is_a?(ClientLoginFetcher)
            raise(GoogleSpreadsheet::Error,
                "Cannot call auth_tokens for session created by " +
                "login_with_oauth.")
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
          doc = request(
              :get, "https://spreadsheets.google.com/feeds/spreadsheets/private/full?#{query}")
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
        #     "https://spreadsheets.google.com/feeds/" +
        #     "worksheets/pz7XtlQC-PYx-jrVMJErTcg/private/full")
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
        #     "http://spreadsheets.google.com/feeds/" +
        #     "cells/pz7XtlQC-PYxNmbBVgyiNWg/od6/private/full")
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
            <atom:entry
                xmlns:atom="http://www.w3.org/2005/Atom"
                xmlns:docs="http://schemas.google.com/docs/2007">
              <atom:category
                  scheme="http://schemas.google.com/g/2005#kind"
                  term="http://schemas.google.com/docs/2007#spreadsheet"
                  label="spreadsheet"/>
              <atom:title>#{h(title)}</atom:title>
            </atom:entry>
          EOS

          doc = request(:post, feed_url, :data => xml, :auth => :writely)
          ss_url = doc.css(
            "link[@rel='http://schemas.google.com/spreadsheets/2006#worksheetsfeed']")[0]["href"]
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
        
        def inspect
          return "#<%p:0x%x>" % [self.class, self.object_id]
        end

      private

        def convert_response(response, response_type)
          case response_type
            when :xml
              return Nokogiri.XML(response.body)
            when :raw
              return response.body
            else
              raise(GoogleSpreadsheet::Error,
                  "Unknown params[:response_type]: %s" % response_type)
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
            :data => encode_query(params),
            :auth => :none,
            :header => header,
            :response_type => :raw)
          return response.slice(/^Auth=(.*)$/, 1)
        end

    end

end
