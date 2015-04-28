# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "json"
require "google/api_client"

require "google_drive/session"


module GoogleDrive

    # Authenticates with given OAuth2 token.
    #
    # +access_token+ can be either OAuth2 access_token string, or OAuth2::AccessToken.
    #
    # OAuth2 code example for Web apps:
    #
    #   require "rubygems"
    #   require "google/api_client"
    #   client = Google::APIClient.new
    #   auth = client.authorization
    #   # Follow "Create a client ID and client secret" in
    #   # https://developers.google.com/drive/web/auth/web-server] to get a client ID and client secret.
    #   auth.client_id = "YOUR CLIENT ID"
    #   auth.client_secret = "YOUR CLIENT SECRET"
    #   auth.scope =
    #       "https://www.googleapis.com/auth/drive " +
    #       "https://spreadsheets.google.com/feeds/"
    #   auth.redirect_uri = "http://example.com/redirect"
    #   auth_url = auth.authorization_uri
    #   # Redirect the user to auth_url and get authorization code from redirect URL.
    #   auth.code = authorization_code
    #   auth.fetch_access_token!
    #   session = GoogleDrive.login_with_oauth(auth.access_token)
    #
    # auth.access_token expires in 1 hour. If you want to restore a session afterwards, you can store
    # auth.refresh_token somewhere after auth.fetch_access_token! above, and use this code:
    #
    #   require "rubygems"
    #   require "google/api_client"
    #   client = Google::APIClient.new
    #   auth = client.authorization
    #   # Follow "Create a client ID and client secret" in
    #   # https://developers.google.com/drive/web/auth/web-server] to get a client ID and client secret.
    #   auth.client_id = "YOUR CLIENT ID"
    #   auth.client_secret = "YOUR CLIENT SECRET"
    #   auth.scope =
    #       "https://www.googleapis.com/auth/drive " +
    #       "https://spreadsheets.google.com/feeds/"
    #   auth.redirect_uri = "http://example.com/redirect"
    #   auth.refresh_token = refresh_token
    #   auth.fetch_access_token!
    #   session = GoogleDrive.login_with_oauth(auth.access_token)
    #
    # OAuth2 code example for command-line apps:
    #
    #   require "rubygems"
    #   require "google/api_client"
    #   client = Google::APIClient.new
    #   auth = client.authorization
    #   # Follow "Create a client ID and client secret" in
    #   # https://developers.google.com/drive/web/auth/web-server] to get a client ID and client secret.
    #   auth.client_id = "YOUR CLIENT ID"
    #   auth.client_secret = "YOUR CLIENT SECRET"
    #   auth.scope =
    #       "https://www.googleapis.com/auth/drive " +
    #       "https://spreadsheets.google.com/feeds/"
    #   auth.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
    #   print("1. Open this page:\n%s\n\n" % auth.authorization_uri)
    #   print("2. Enter the authorization code shown in the page: ")
    #   auth.code = $stdin.gets.chomp
    #   auth.fetch_access_token!
    #   session = GoogleDrive.login_with_oauth(auth.access_token)
    #
    # See this document for details:
    #
    # - https://developers.google.com/drive/web/about-auth
    def self.login_with_oauth(client_or_access_token, proxy = nil)
      return Session.new(client_or_access_token, proxy)
    end

    # Restores GoogleDrive::Session from +path+ and returns it.
    # If +path+ doesn't exist or authentication has failed, prompts the user to authorize the access,
    # stores the session to +path+ and returns it.
    #
    # +path+ defaults to ENV["HOME"] + "/.ruby_google_drive.token".
    #
    # You can specify your own OAuth +client_id+ and +client_secret+. Otherwise the default one is used.
    def self.saved_session(path = nil, proxy = nil, client_id = nil, client_secret = nil)

      if proxy
        raise(
            ArgumentError,
            "Specifying a proxy object is no longer supported. Set ENV[\"http_proxy\"] instead.")
      end

      if !client_id && !client_secret
        client_id = "452925651630-egr1f18o96acjjvphpbbd1qlsevkho1d.apps.googleusercontent.com"
        client_secret = "1U3-Krii5x1oLPrwD5zgn-ry"
      elsif !client_id || !client_secret
        raise(ArgumentError, "client_id and client_secret must be both specified or both omitted")
      end

      path ||= ENV["HOME"] + "/.ruby_google_drive.token"
      if ::File.exist?(path)
        lines = ::File.readlines(path)
        case lines.size
          when 1
            token_data = JSON.parse(lines[0].chomp())
          when 2
            # Old format.
            token_data = nil
          else
            raise(ArgumentError, "Not a token file: %s" % path)
        end
      else
        token_data = nil
      end

      client = Google::APIClient.new(
          :application_name => "google_drive Ruby library",
          :application_version => "0.4.0"
      )
      auth = client.authorization
      auth.client_id = client_id
      auth.client_secret = client_secret
      auth.scope =
          "https://www.googleapis.com/auth/drive " +
          "https://spreadsheets.google.com/feeds/"
      auth.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"

      if token_data

        auth.refresh_token = token_data["refresh_token"]
        auth.fetch_access_token!()

      else

        $stderr.print("\n1. Open this page:\n%s\n\n" % auth.authorization_uri)
        $stderr.print("2. Enter the authorization code shown in the page: ")
        auth.code = $stdin.gets().chomp()
        auth.fetch_access_token!()
        token_data = {"refresh_token" => auth.refresh_token}
        open(path, "w", 0600) do |f|
          f.puts(JSON.dump(token_data))
        end

      end

      return GoogleDrive.login_with_oauth(client)

    end
    
end
