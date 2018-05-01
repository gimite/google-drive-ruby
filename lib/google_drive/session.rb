# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require 'cgi'
require 'stringio'

require 'rubygems'
require 'nokogiri'
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
require 'google_drive/access_token_credentials'

module GoogleDrive
  # A session for Google Drive operations.
  #
  # Use from_credentials, from_access_token, from_service_account_key or
  # from_config class method to construct a GoogleDrive::Session object.
  class Session
    include(Util)
    extend(Util)

    DEFAULT_SCOPE = [
      'https://www.googleapis.com/auth/drive',
      'https://spreadsheets.google.com/feeds/'
    ].freeze

    # Equivalent of either from_credentials or from_access_token.
    def self.login_with_oauth(credentials_or_access_token, proxy = nil)
      Session.new(credentials_or_access_token, proxy)
    end

    # Creates a dummy GoogleDrive::Session object for testing.
    def self.new_dummy
      Session.new(nil)
    end

    # Constructs a GoogleDrive::Session object from OAuth2 credentials such as
    # Google::Auth::UserRefreshCredentials.
    #
    # See
    # https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md
    # for a usage example.
    def self.from_credentials(credentials)
      Session.new(credentials)
    end

    # Constructs a GoogleDrive::Session object from OAuth2 access token string.
    def self.from_access_token(access_token)
      Session.new(access_token)
    end

    # Constructs a GoogleDrive::Session object from a service account key JSON.
    #
    # You can pass either the path to a JSON file, or an IO-like object with the
    # JSON.
    #
    # See
    # https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md
    # for a usage example.
    def self.from_service_account_key(
        json_key_path_or_io, scope = DEFAULT_SCOPE
    )
      if json_key_path_or_io.is_a?(String)
        open(json_key_path_or_io) do |f|
          from_service_account_key(f, scope)
        end
      else
        credentials = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: json_key_path_or_io, scope: scope
        )
        Session.new(credentials)
      end
    end

    # Returns GoogleDrive::Session constructed from a config JSON file at
    # +config+.
    #
    # +config+ is the path to the config file.
    #
    # This will prompt the credential via command line for the first time and
    # save it to +config+ for later usages.
    #
    # See
    # https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md
    # for a usage example.
    #
    # You can also provide a config object that must respond to:
    #   client_id
    #   client_secret
    #   refesh_token
    #   refresh_token=
    #   scope
    #   scope=
    #   save
    def self.from_config(config, options = {})
      if config.is_a?(String)
        config_path = config
        config = Config.new(config_path)
        if config.type == 'service_account'
          return from_service_account_key(
            config_path, options[:scope] || DEFAULT_SCOPE
          )
        end
      end

      config.scope ||= DEFAULT_SCOPE

      if options[:client_id] && options[:client_secret]
        config.client_id = options[:client_id]
        config.client_secret = options[:client_secret]
      end
      if !config.client_id && !config.client_secret
        config.client_id =
          '452925651630-egr1f18o96acjjvphpbbd1qlsevkho1d.' \
          'apps.googleusercontent.com'
        config.client_secret = '1U3-Krii5x1oLPrwD5zgn-ry'
      elsif !config.client_id || !config.client_secret
        raise(
          ArgumentError,
          'client_id and client_secret must be both specified or both omitted'
        )
      end

      credentials = Google::Auth::UserRefreshCredentials.new(
        client_id: config.client_id,
        client_secret: config.client_secret,
        scope: config.scope,
        redirect_uri: 'urn:ietf:wg:oauth:2.0:oob'
      )

      if config.refresh_token
        credentials.refresh_token = config.refresh_token
        credentials.fetch_access_token!
      else
        $stderr.print(
          format("\n1. Open this page:\n%s\n\n", credentials.authorization_uri)
        )
        $stderr.print('2. Enter the authorization code shown in the page: ')
        credentials.code = $stdin.gets.chomp
        credentials.fetch_access_token!
        config.refresh_token = credentials.refresh_token
      end

      config.save

      Session.new(credentials)
    end

    def initialize(credentials_or_access_token, proxy = nil)
      if proxy
        raise(
          ArgumentError,
          'Specifying a proxy object is no longer supported. ' \
          'Set ENV["http_proxy"] instead.'
        )
      end

      if credentials_or_access_token
        if credentials_or_access_token.is_a?(String)
          credentials = AccessTokenCredentials.new(credentials_or_access_token)
        # Equivalent of credentials_or_access_token.is_a?(OAuth2::AccessToken),
        # without adding dependency to "oauth2" library.
        elsif credentials_or_access_token
              .class
              .ancestors
              .any? { |m| m.name == 'OAuth2::AccessToken' }
          credentials =
            AccessTokenCredentials.new(credentials_or_access_token.token)
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

    # Returns list of files for the user as array of GoogleDrive::File or its
    # subclass. You can specify parameters documented at
    # https://developers.google.com/drive/v3/web/search-parameters
    #
    # e.g.
    #   session.files
    #   session.files(q: "name = 'hoge'")
    #   # Same as above with a placeholder
    #   session.files(q: ["name = ?", "hoge"])
    #
    # By default, it returns the first 100 files. You can get all files by
    # calling with a block:
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
        method: drive.method(:list_files),
        parameters: { fields: '*', supports_team_drives: true }.merge(params),
        items_method_name: :files,
        converter: proc { |af| wrap_api_file(af) },
        &block
      )
    end

    # Returns a file (including a spreadsheet and a folder) whose title exactly
    # matches +title+.
    #
    # Returns an instance of GoogleDrive::File or its subclass
    # (GoogleDrive::Spreadsheet, GoogleDrive::Collection). Returns nil if not
    # found. If multiple files with the +title+ are found, returns one of them.
    #
    # If given an Array, traverses folders by title. e.g.:
    #   session.file_by_title(
    #     ["myfolder", "mysubfolder/even/w/slash", "myfile"])
    def file_by_title(title)
      if title.is_a?(Array)
        root_collection.file_by_title(title)
      else
        files(q: ['name = ?', title], page_size: 1)[0]
      end
    end

    alias file_by_name file_by_title

    # Returns a file (including a spreadsheet and a folder) with a given +id+.
    #
    # Returns an instance of GoogleDrive::File or its subclass
    # (GoogleDrive::Spreadsheet, GoogleDrive::Collection).
    def file_by_id(id)
      api_file = drive.get_file(id, fields: '*', supports_team_drives: true)
      wrap_api_file(api_file)
    end

    # Returns a file (including a spreadsheet and a folder) with a given +url+.
    # +url+ must be the URL of the page you open to access a
    # document/spreadsheet in your browser.
    #
    # Returns an instance of GoogleDrive::File or its subclass
    # (GoogleDrive::Spreadsheet, GoogleDrive::Collection).
    def file_by_url(url)
      file_by_id(url_to_id(url))
    end

    # Returns list of spreadsheets for the user as array of
    # GoogleDrive::Spreadsheet.
    # You can specify parameters documented at
    # https://developers.google.com/drive/v3/web/search-parameters
    #
    # e.g.
    #   session.spreadsheets
    #   session.spreadsheets(q: "name = 'hoge'")
    #   # Same as above with a placeholder
    #   session.spreadsheets(q: ["name = ?", "hoge"])
    #
    # By default, it returns the first 100 spreadsheets. See document of files
    # method for how to get all spreadsheets.
    def spreadsheets(params = {}, &block)
      params = convert_params(params)
      query  = construct_and_query(
        [
          "mimeType = 'application/vnd.google-apps.spreadsheet'",
          params[:q]
        ]
      )
      files(params.merge(q: query), &block)
    end

    # Returns GoogleDrive::Spreadsheet with given +key+.
    #
    # e.g.
    #   # https://docs.google.com/spreadsheets/d/1L3-kvwJblyW_TvjYD-7pE-AXxw5_bkb6S_MljuIPVL0/edit
    #   session.spreadsheet_by_key(
    #     "1L3-kvwJblyW_TvjYD-7pE-AXxw5_bkb6S_MljuIPVL0")
    def spreadsheet_by_key(key)
      file = file_by_id(key)
      unless file.is_a?(Spreadsheet)
        raise(
          GoogleDrive::Error,
          format('The file with the ID is not a spreadsheet: %s', key)
        )
      end
      file
    end

    # Returns GoogleDrive::Spreadsheet with given +url+. You must specify either
    # of:
    # - URL of the page you open to access the spreadsheet in your browser
    # - URL of worksheet-based feed of the spreadseet
    #
    # e.g.
    #   session.spreadsheet_by_url(
    #     "https://docs.google.com/spreadsheets/d/" \
    #     "1L3-kvwJblyW_TvjYD-7pE-AXxw5_bkb6S_MljuIPVL0/edit")
    def spreadsheet_by_url(url)
      file = file_by_url(url)
      unless file.is_a?(Spreadsheet)
        raise(
          GoogleDrive::Error,
          format('The file with the URL is not a spreadsheet: %s', url)
        )
      end
      file
    end

    # Returns GoogleDrive::Spreadsheet with given +title+.
    # Returns nil if not found. If multiple spreadsheets with the +title+ are
    # found, returns one of them.
    def spreadsheet_by_title(title)
      spreadsheets(q: ['name = ?', title], page_size: 1)[0]
    end

    alias spreadsheet_by_name spreadsheet_by_title

    # Returns GoogleDrive::Worksheet with given +url+.
    # You must specify URL of either worksheet feed or cell-based feed of the
    # worksheet.
    #
    # e.g.:
    #   # Worksheet feed URL
    #   session.worksheet_by_url(
    #     "https://spreadsheets.google.com/feeds/worksheets/" \
    #     "1smypkyAz4STrKO4Zkos5Z4UPUJKvvgIza32LnlQ7OGw/private/full/od7")
    #   # Cell-based feed URL
    #   session.worksheet_by_url(
    #     "https://spreadsheets.google.com/feeds/cells/" \
    #     "1smypkyAz4STrKO4Zkos5Z4UPUJKvvgIza32LnlQ7OGw/od7/private/full")
    def worksheet_by_url(url)
      case url
      when %r{^https?://spreadsheets.google.com/feeds/worksheets/.*/.*/full/.*$}
        worksheet_feed_url = url
      when %r{^https?://spreadsheets.google.com/feeds/cells/(.*)/(.*)/private/full((\?.*)?)$}
        worksheet_feed_url =
          'https://spreadsheets.google.com/feeds/worksheets/' \
          "#{Regexp.last_match(1)}/private/full/" \
          "#{Regexp.last_match(2)}#{Regexp.last_match(3)}"
      else
        raise(
          GoogleDrive::Error,
          'URL is neither a worksheet feed URL nor a cell-based feed URL: ' \
          "#{url}"
        )
      end

      worksheet_feed_entry = request(:get, worksheet_feed_url)
      Worksheet.new(self, nil, worksheet_feed_entry)
    end

    # Returns the root folder.
    def root_collection
      @root_collection ||= file_by_id('root')
    end

    alias root_folder root_collection

    # Returns the top-level folders (direct children of the root folder).
    #
    # By default, it returns the first 100 folders. See document of files method
    # for how to get all folders.
    def collections(params = {}, &block)
      root_collection.subcollections(params, &block)
    end

    alias folders collections

    # Returns a top-level folder whose title exactly matches +title+ as
    # GoogleDrive::Collection.
    # Returns nil if not found. If multiple folders with the +title+ are found,
    # returns one of them.
    def collection_by_title(title)
      root_collection.subcollection_by_title(title)
    end

    alias folders_by_name collection_by_title

    # Returns GoogleDrive::Collection with given +url+.
    #
    # You must specify the URL of the page you get when you go to
    # https://drive.google.com/ with your browser and open a folder.
    #
    # e.g.
    #   session.collection_by_url(
    #     "https://drive.google.com/drive/folders/" \
    #     "1u99gpfHIk08RVK5q_vXxUqkxR1r6FUJH")
    def collection_by_url(url)
      file = file_by_url(url)
      unless file.is_a?(Collection)
        raise(
          GoogleDrive::Error,
          format('The file with the URL is not a folder: %s', url)
        )
      end
      file
    end

    alias folder_by_url collection_by_url

    # Creates a top-level folder with given title. Returns GoogleDrive::Collection
    # object.
    def create_collection(title, file_properties = {})
      create_file(title, file_properties.merge(mime_type: 'application/vnd.google-apps.folder'))
    end

    alias create_folder create_collection

    # Creates a spreadsheet with given title. Returns GoogleDrive::Spreadsheet
    # object.
    #
    # e.g.
    #   session.create_spreadsheet("My new sheet")
    def create_spreadsheet(title = 'Untitled', file_properties = {})
      create_file(title, file_properties.merge(mime_type: 'application/vnd.google-apps.spreadsheet'))
    end

    # Creates a file with given title and properties. Returns objects
    # with the following types: GoogleDrive::Spreadsheet, GoogleDrive::File,
    # GoogleDrive::Collection
    #
    # You can pass a MIME Type using the file_properties-function parameter,
    # for example: create_file('Document Title', mime_type: 'application/vnd.google-apps.document')
    #
    # A list of available Drive MIME Types can be found here:
    # https://developers.google.com/drive/v3/web/mime-types
    def create_file(title, file_properties = {})
      file_metadata = {
        name: title,
      }.merge(file_properties)

      file = drive.create_file(
        file_metadata, fields: '*', supports_team_drives: true
      )

      wrap_api_file(file)
    end

    # Uploads a file with the given +title+ and +content+.
    # Returns a GoogleSpreadsheet::File object.
    #
    # e.g.
    #   # Uploads and converts to a Google Docs document:
    #   session.upload_from_string(
    #       "Hello world.", "Hello", content_type: "text/plain")
    #
    #   # Uploads without conversion:
    #   session.upload_from_string(
    #       "Hello world.", "Hello", content_type: "text/plain", convert: false)
    #
    #   # Uploads and converts to a Google Spreadsheet:
    #   session.upload_from_string(
    #     "hoge\tfoo\n", "Hoge", content_type: "text/tab-separated-values")
    #   session.upload_from_string(
    #     "hoge,foo\n", "Hoge", content_type: "text/tsv")
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
    #   session.upload_from_file("/path/to/hoge.txt", "Hoge", convert: false)
    #
    #   # Uploads with explicit content type:
    #   session.upload_from_file(
    #     "/path/to/hoge", "Hoge", content_type: "text/plain")
    #
    #   # Uploads a text file and converts to a Google Spreadsheet:
    #   session.upload_from_file("/path/to/hoge.csv", "Hoge")
    #   session.upload_from_file(
    #     "/path/to/hoge", "Hoge", content_type: "text/csv")
    def upload_from_file(path, title = nil, params = {})
      # TODO: Add a feature to upload to a folder.
      file_name = ::File.basename(path)
      default_content_type =
        EXT_TO_CONTENT_TYPE[::File.extname(file_name).downcase] ||
        'application/octet-stream'
      upload_from_source(
        path,
        title || file_name,
        { content_type: default_content_type }.merge(params)
      )
    end

    # Uploads a file. Reads content from +io+.
    # Returns a GoogleDrive::File object.
    def upload_from_io(io, title = 'Untitled', params = {})
      upload_from_source(io, title, params)
    end

    # @api private
    def wrap_api_file(api_file)
      case api_file.mime_type
      when 'application/vnd.google-apps.folder'
        Collection.new(self, api_file)
      when 'application/vnd.google-apps.spreadsheet'
        Spreadsheet.new(self, api_file)
      else
        File.new(self, api_file)
      end
    end

    # @api private
    def execute_paged!(opts, &block)
      if block
        page_token = nil
        loop do
          parameters =
            (opts[:parameters] || {}).merge(page_token: page_token)
          (items, page_token) =
            execute_paged!(opts.merge(parameters: parameters))
          items.each(&block)
          break unless page_token
        end

      elsif opts[:parameters] && opts[:parameters].key?(:page_token)
        response = opts[:method].call(opts[:parameters])
        items    = response.__send__(opts[:items_method_name]).map do |item|
          opts[:converter] ? opts[:converter].call(item) : item
        end
        [items, response.next_page_token]

      else
        parameters = (opts[:parameters] || {}).merge(page_token: nil)
        (items,) = execute_paged!(opts.merge(parameters: parameters))
        items
      end
    end

    # @api private
    def request(method, url, params = {})
      # Always uses HTTPS.
      url           = url.gsub(%r{^http://}, 'https://')
      data          = params[:data]
      auth          = params[:auth] || :wise
      response_type = params[:response_type] || :xml

      extra_header = if params[:header]
                       params[:header]
                     elsif data
                       {
                         'Content-Type' => 'application/atom+xml;charset=utf-8'
                       }
                     else
                       {}
                     end
      extra_header = { 'GData-Version' => '3.0' }.merge(extra_header)

      loop do
        response = @fetcher.request_raw(method, url, data, extra_header, auth)
        next if response.code == '401' && @on_auth_fail && @on_auth_fail.call
        unless response.code =~ /^2/
          raise(
            (response.code == '401' ? AuthenticationError : ResponseCodeError)
              .new(response.code, response.body, method, url)
          )
        end
        return convert_response(response, response_type)
      end
    end

    def inspect
      format('#<%p:0x%x>', self.class, object_id)
    end

    private

    def upload_from_source(source, title, params = {})
      api_params = {
        upload_source: source,
        content_type: 'application/octet-stream',
        fields: '*',
        supports_team_drives: true
      }
      for k, v in params
        unless %i[convert convert_mime_type parents].include?(k)
          api_params[k] = v
        end
      end

      file_metadata = { name: title }
      content_type = api_params[:content_type]
      if params[:convert_mime_type]
        file_metadata[:mime_type] = params[:convert_mime_type]
      elsif params.fetch(:convert, true) &&
            IMPORTABLE_CONTENT_TYPE_MAP.key?(content_type)
        file_metadata[:mime_type] = IMPORTABLE_CONTENT_TYPE_MAP[content_type]
      end
      file_metadata[:parents] = params[:parents] if params[:parents]

      file = drive.create_file(file_metadata, api_params)
      wrap_api_file(file)
    end

    def convert_response(response, response_type)
      case response_type
      when :xml
        Nokogiri.XML(response.body)
      when :raw
        response.body
      when :response
        response
      else
        raise(GoogleDrive::Error,
              format('Unknown params[:response_type]: %s', response_type))
      end
    end

    def url_to_id(url)
      uri = URI.parse(url)
      if ['spreadsheets.google.com', 'docs.google.com', 'drive.google.com']
         .include?(uri.host)
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
          # Human-readable new folder page.
        when /^\/drive\/[^\/]+\/([^\/]+)/
          return Regexp.last_match(1)
          # Human-readable old folder view.
        when /\/folderview$/
          if (uri.query || '').split(/&/).find { |s| s =~ /^id=(.*)$/ }
            return Regexp.last_match(1)
          end
          # Human-readable old spreadsheet.
        when /\/ccc$/
          if (uri.query || '').split(/&/).find { |s| s =~ /^key=(.*)$/ }
            return Regexp.last_match(1)
          end
        end
        case uri.fragment
          # Human-readable old folder page.
        when /^folders\/(.+)$/
          return Regexp.last_match(1)
        end
      end
      raise(
        GoogleDrive::Error,
        format('The given URL is not a known Google Drive URL: %s', url)
      )
    end
  end
end
