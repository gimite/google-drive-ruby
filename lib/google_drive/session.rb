# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require 'cgi'
require 'stringio'

require 'rubygems'
require 'nokogiri'
require 'oauth'
require 'oauth2'
require 'googleauth'

require 'google_drive/util'
require 'google_drive/api_client_fetcher'
require 'google_drive/error'
require 'google_drive/authentication_error'
require 'google_drive/response_code_error'
require 'google_drive/spreadsheet'
require 'google_drive/worksheet'
require 'google_drive/collection'
require 'google_drive/file'
require 'google_drive/config'

module GoogleDrive
  # Use GoogleDrive.login_with_oauth or GoogleDrive.saved_session to get
  # GoogleDrive::Session object.
  class Session
    include(Util)
    extend(Util)

    # The same as GoogleDrive.login_with_oauth.
    def self.login_with_oauth(credentials_or_access_token, proxy = nil)
      Session.new(credentials_or_access_token, proxy)
    end

    # Creates a dummy GoogleDrive::Session object for testing.
    def self.new_dummy
      Session.new(nil)
    end

    def initialize(credentials_or_access_token, proxy = nil)
      if proxy
        fail(
          ArgumentError,
          "Specifying a proxy object is no longer supported. Set ENV[\"http_proxy\"] instead.")
      end

      if credentials_or_access_token
        case credentials_or_access_token
        when String
          credentials = Google::Auth::UserRefreshCredentials.new(
            access_token: credentials_or_access_token)
        when OAuth2::AccessToken
          credentials = Google::Auth::UserRefreshCredentials.new(
            access_token: credentials_or_access_token.token)
        when OAuth::AccessToken
          fail(
            ArgumentError,
            'OAuth1 is no longer supported. Use OAuth2 instead.')
        else
          credentials = credentials_or_access_token
        end
        @fetcher = ApiClientFetcher.new(credentials)
      else
        @fetcher = nil
      end
    end

    # Proc or Method called when authentication has failed.
    # When this function returns +true+, it tries again.
    attr_accessor :on_auth_fail

    # Returns an instance of Google::Apis::DriveV3::DriveService.
    def drive
      @fetcher.drive
    end

    # Returns list of files for the user as array of GoogleDrive::File or its subclass.
    # You can specify parameters documented at
    # https://developers.google.com/drive/v3/web/search-parameters
    #
    # e.g.
    #   session.files
    #   session.files(q: "name = 'hoge'")
    #   session.files(q: ["name = ?", "hoge"])  # Same as above with a placeholder
    #
    # By default, it returns the first 100 files. You can get all files by calling with a block:
    #   session.files do |file|
    #     p file
    #   end
    # Or passing "pageToken" parameter:
    #   page_token = nil
    #   begin
    #     (files, page_token) = session.files(page_token: page_token)
    #     p files
    #   end while page_token
    def files(params = {}, &block)
      params = convert_params(params)
      execute_paged!(
        method: self.drive.method(:list_files),
        parameters: {fields: '*'}.merge(params),
        items_method_name: :files,
        converter: proc { |af| wrap_api_file(af) },
        &block)
    end

    # Returns GoogleDrive::File or its subclass whose title exactly matches +title+.
    # Returns nil if not found. If multiple files with the +title+ are found, returns
    # one of them.
    #
    # If given an Array, traverses collections by title. e.g.
    #   session.file_by_title(["myfolder", "mysubfolder/even/w/slash", "myfile"])
    def file_by_title(title)
      if title.is_a?(Array)
        root_collection.file_by_title(title)
      else
        files(q: ['name = ?', title], page_size: 1)[0]
      end
    end

    # Returns GoogleDrive::File or its subclass with a given +id+.
    def file_by_id(id)
      api_file = self.drive.get_file(id, fields: '*')
      wrap_api_file(api_file)
    end

    # Returns GoogleDrive::File or its subclass with a given +url+. +url+ must be eitehr of:
    # - URL of the page you open to access a document/spreadsheet in your browser
    # - URL of worksheet-based feed of a spreadseet
    def file_by_url(url)
      file_by_id(url_to_id(url))
    end

    # Returns list of spreadsheets for the user as array of GoogleDrive::Spreadsheet.
    # You can specify parameters documented at
    # https://developers.google.com/drive/v3/web/search-parameters
    #
    # e.g.
    #   session.spreadsheets
    #   session.spreadsheets(q: "name = 'hoge'")
    #   session.spreadsheets(q: ["name = ?", "hoge"])  # Same as above with a placeholder
    #
    # By default, it returns the first 100 spreadsheets. See document of files method for how to get
    # all spreadsheets.
    def spreadsheets(params = {}, &block)
      params = convert_params(params)
      query  = construct_and_query([
        "mimeType = 'application/vnd.google-apps.spreadsheet'",
        params[:q]
      ])
      files(params.merge(q: query), &block)
    end

    # Returns GoogleDrive::Spreadsheet with given +key+.
    #
    # e.g.
    #   # https://docs.google.com/spreadsheets/d/1L3-kvwJblyW_TvjYD-7pE-AXxw5_bkb6S_MljuIPVL0/edit
    #   session.spreadsheet_by_key("1L3-kvwJblyW_TvjYD-7pE-AXxw5_bkb6S_MljuIPVL0")
    def spreadsheet_by_key(key)
      file = file_by_id(key)
      unless file.is_a?(Spreadsheet)
        fail(GoogleDrive::Error, 'The file with the ID is not a spreadsheet: %s' % key)
      end
      file
    end

    # Returns GoogleDrive::Spreadsheet with given +url+. You must specify either of:
    # - URL of the page you open to access the spreadsheet in your browser
    # - URL of worksheet-based feed of the spreadseet
    #
    # e.g.
    #   session.spreadsheet_by_url(
    #     "https://docs.google.com/spreadsheets/d/1L3-kvwJblyW_TvjYD-7pE-AXxw5_bkb6S_MljuIPVL0/edit")
    #   session.spreadsheet_by_url(
    #     "https://spreadsheets.google.com/feeds/" +
    #     "worksheets/1L3-kvwJblyW_TvjYD-7pE-AXxw5_bkb6S_MljuIPVL0/private/full")
    def spreadsheet_by_url(url)
      file = file_by_url(url)
      unless file.is_a?(Spreadsheet)
        fail(GoogleDrive::Error, 'The file with the URL is not a spreadsheet: %s' % url)
      end
      file
    end

    # Returns GoogleDrive::Spreadsheet with given +title+.
    # Returns nil if not found. If multiple spreadsheets with the +title+ are found, returns
    # one of them.
    def spreadsheet_by_title(title)
      spreadsheets(q: ['name = ?', title], page_size: 1)[0]
    end

    # Returns GoogleDrive::Worksheet with given +url+.
    # You must specify URL of cell-based feed of the worksheet.
    #
    # e.g.
    #   session.worksheet_by_url(
    #     "http://spreadsheets.google.com/feeds/" +
    #     "cells/pz7XtlQC-PYxNmbBVgyiNWg/od6/private/full")
    def worksheet_by_url(url)
      unless url =~
             %r{^https?://spreadsheets.google.com/feeds/cells/(.*)/(.*)/private/full((\?.*)?)$}
        fail(GoogleDrive::Error, "URL is not a cell-based feed URL: #{url}")
      end
      worksheet_feed_url = "https://spreadsheets.google.com/feeds/worksheets/" +
        "#{Regexp.last_match(1)}/private/full/#{Regexp.last_match(2)}#{Regexp.last_match(3)}"
      worksheet_feed_entry = request(:get, worksheet_feed_url)
      Worksheet.new(self, nil, worksheet_feed_entry)
    end

    # Returns the root collection.
    def root_collection
      @root_collection ||= file_by_id('root')
    end

    # Returns the top-level collections (direct children of the root collection).
    #
    # By default, it returns the first 100 collections. See document of files method for how to get
    # all collections.
    def collections(params = {}, &block)
      root_collection.subcollections(params, &block)
    end

    # Returns a top-level collection whose title exactly matches +title+ as
    # GoogleDrive::Collection.
    # Returns nil if not found. If multiple collections with the +title+ are found, returns
    # one of them.
    def collection_by_title(title)
      root_collection.subcollection_by_title(title)
    end

    # Returns GoogleDrive::Collection with given +url+.
    # You must specify either of:
    # - URL of the page you get when you go to https://docs.google.com/ with your browser and
    #   open a collection
    # - URL of collection (folder) feed
    #
    # e.g.
    #   session.collection_by_url(
    #     "https://drive.google.com/#folders/" +
    #     "0B9GfDpQ2pBVUODNmOGE0NjIzMWU3ZC00NmUyLTk5NzEtYaFkZjY1MjAyxjMc")
    #   session.collection_by_url(
    #     "http://docs.google.com/feeds/default/private/full/folder%3A" +
    #     "0B9GfDpQ2pBVUODNmOGE0NjIzMWU3ZC00NmUyLTk5NzEtYaFkZjY1MjAyxjMc")
    def collection_by_url(url)
      file = file_by_url(url)
      unless file.is_a?(Collection)
        fail(GoogleDrive::Error, 'The file with the URL is not a collection: %s' % url)
      end
      file
    end

    # Creates new spreadsheet and returns the new GoogleDrive::Spreadsheet.
    #
    # e.g.
    #   session.create_spreadsheet("My new sheet")
    def create_spreadsheet(title = 'Untitled')
      file_metadata = {
        name:    title,
        mime_type: 'application/vnd.google-apps.spreadsheet'
      }
      file = self.drive.create_file(file_metadata, fields: '*')
      wrap_api_file(file)
    end

    # Uploads a file with the given +title+ and +content+.
    # Returns a GoogleSpreadsheet::File object.
    #
    # e.g.
    #   # Uploads and converts to a Google Docs document:
    #   session.upload_from_string(
    #       "Hello world.", "Hello", :content_type => "text/plain")
    #
    #   # Uploads without conversion:
    #   session.upload_from_string(
    #       "Hello world.", "Hello", :content_type => "text/plain", :convert => false)
    #
    #   # Uploads and converts to a Google Spreadsheet:
    #   session.upload_from_string("hoge\tfoo\n", "Hoge", :content_type => "text/tab-separated-values")
    #   session.upload_from_string("hoge,foo\n", "Hoge", :content_type => "text/tsv")
    def upload_from_string(content, title = 'Untitled', params = {})
      upload_from_source(StringIO.new(content), title, params)
    end

    # Uploads a local file.
    # Returns a GoogleSpreadsheet::File object.
    #
    # e.g.
    #   # Uploads a text file and converts to a Google Docs document:
    #   session.upload_from_file("/path/to/hoge.txt")
    #
    #   # Uploads without conversion:
    #   session.upload_from_file("/path/to/hoge.txt", "Hoge", :convert => false)
    #
    #   # Uploads with explicit content type:
    #   session.upload_from_file("/path/to/hoge", "Hoge", :content_type => "text/plain")
    #
    #   # Uploads a text file and converts to a Google Spreadsheet:
    #   session.upload_from_file("/path/to/hoge.csv", "Hoge")
    #   session.upload_from_file("/path/to/hoge", "Hoge", :content_type => "text/csv")
    def upload_from_file(path, title = nil, params = {})
      # TODO: Add a feature to upload to a folder.
      file_name = ::File.basename(path)
      default_content_type =
        EXT_TO_CONTENT_TYPE[::File.extname(file_name).downcase] ||
        'application/octet-stream'
      upload_from_source(
        path,
        title || file_name,
        {content_type: default_content_type}.merge(params))
    end

    # Uploads a file. Reads content from +io+.
    # Returns a GoogleSpreadsheet::File object.
    def upload_from_io(io, title = 'Untitled', params = {})
      upload_from_source(io, title, params)
    end

    def wrap_api_file(api_file) #:nodoc:
      case api_file.mime_type
      when 'application/vnd.google-apps.folder'
        return Collection.new(self, api_file)
      when 'application/vnd.google-apps.spreadsheet'
        return Spreadsheet.new(self, api_file)
      else
        return File.new(self, api_file)
      end
    end

    def execute_paged!(opts, &block) #:nodoc:
      if block

        page_token = nil
        begin
          parameters          = (opts[:parameters] || {}).merge({page_token: page_token})
          (items, page_token) = execute_paged!(opts.merge(parameters: parameters))
          items.each(&block)
        end while page_token

      elsif opts[:parameters] && opts[:parameters].key?(:page_token)

        response = opts[:method].call(opts[:parameters])
        items    = response.__send__(opts[:items_method_name]).map do |item|
          opts[:converter] ? opts[:converter].call(item) : item
        end
        return [items, response.next_page_token]

      else
        parameters               = (opts[:parameters] || {}).merge({page_token: nil})
        (items, next_page_token) = execute_paged!(opts.merge(parameters: parameters))
        items
      end
    end

    def request(method, url, params = {}) #:nodoc:
      # Always uses HTTPS.
      url           = url.gsub(%r{^http://}, 'https://')
      data          = params[:data]
      auth          = params[:auth] || :wise
      response_type = params[:response_type] || :xml

      if params[:header]
        extra_header = params[:header]
      elsif data
        extra_header = { 'Content-Type' => 'application/atom+xml;charset=utf-8' }
      else
        extra_header = {}
      end
      extra_header = { 'GData-Version' => '3.0' }.merge(extra_header)

      loop do
        response = @fetcher.request_raw(method, url, data, extra_header, auth)
        next if response.code == '401' && @on_auth_fail && @on_auth_fail.call
        unless response.code =~ /^2/
          fail((response.code == '401' ? AuthenticationError : ResponseCodeError)
                 .new(response.code, response.body, method, url))
        end
        return convert_response(response, response_type)
      end
    end

    def inspect
      '#<%p:0x%x>' % [self.class, object_id]
    end

    private

    def upload_from_source(source, title, params = {})
      api_params = {
        upload_source: source,
        content_type: 'application/octet-stream',
        fields: '*',
      }
      for k, v in params
        if ![:convert, :convert_mime_type].include?(k)
          api_params[k] = v
        end
      end

      file_metadata = { name: title }
      content_type = api_params[:content_type]
      if params[:convert_mime_type]
        file_metadata[:mime_type] = params[:convert_mime_type]
      elsif params.fetch(:convert, true) && IMPORTABLE_CONTENT_TYPE_MAP.key?(content_type)
        file_metadata[:mime_type] = IMPORTABLE_CONTENT_TYPE_MAP[content_type]
      end

      file = self.drive.create_file(file_metadata, api_params)
      wrap_api_file(file)
    end

    def convert_response(response, response_type)
      case response_type
      when :xml
        return Nokogiri.XML(response.body)
      when :raw
        return response.body
      when :response
        return response
      else
        fail(GoogleDrive::Error,
             'Unknown params[:response_type]: %s' % response_type)
      end
    end

    def url_to_id(url)
      uri = URI.parse(url)
      if ['spreadsheets.google.com', 'docs.google.com', 'drive.google.com'].include?(uri.host)
        case uri.path
          # Document feed.
        when /^\/feeds\/\w+\/private\/full\/\w+%3A(.*)$/
          return Regexp.last_match(1)
          # Worksheets feed of a spreadsheet.
        when /^\/feeds\/worksheets\/([^\/]+)/
          return Regexp.last_match(1)
          # Human-readable new spreadsheet/document.
        when /\/d\/([^\/]+)/
          return Regexp.last_match(1)
          # Human-readable new collection page.
        when /^\/drive\/[^\/]+\/([^\/]+)/
          return Regexp.last_match(1)
          # Human-readable old folder view.
        when /\/folderview$/
          return Regexp.last_match(1) if (uri.query || '').split(/&/).find { |s| s =~ /^id=(.*)$/ }
          # Human-readable old spreadsheet.
        when /\/ccc$/
          return Regexp.last_match(1) if (uri.query || '').split(/&/).find { |s| s =~ /^key=(.*)$/ }
        end
        case uri.fragment
          # Human-readable old collection page.
        when /^folders\/(.+)$/
          return Regexp.last_match(1)
        end
      end
      fail(GoogleDrive::Error, 'The given URL is not a known Google Drive URL: %s' % url)
    end
  end
end
