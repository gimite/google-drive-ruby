# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "rubygems"
require "google/api_client"
require "json"

require "google_drive_v0/session"


module GoogleDriveV0

    # Authenticates with given +mail+ and +password+, and returns GoogleDriveV0::Session
    # if succeeds. Raises GoogleDriveV0::AuthenticationError if fails.
    # Google Apps account is supported.
    #
    # +proxy+ is deprecated, and will be removed in the next version.
    def self.login(mail, password, proxy = nil)
      return Session.login(mail, password, proxy)
    end

    # Authenticates with given OAuth2 token.
    #
    # +access_token+ can be either OAuth2 access_token string or OAuth2::AccessToken.
    # Specifying OAuth::AccessToken is deprecated, and will not work in the next version.
    #
    # +proxy+ is deprecated, and will be removed in the next version.
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
    #       :scope =>
    #           "https://docs.google.com/feeds/ " +
    #           "https://docs.googleusercontent.com/ " +
    #           "https://spreadsheets.google.com/feeds/")
    #   # Redirect the user to auth_url and get authorization code from redirect URL.
    #   auth_token = client.auth_code.get_token(
    #       authorization_code, :redirect_uri => "http://example.com/")
    #   session = GoogleDriveV0.login_with_oauth(auth_token.token)
    #
    # Or, from existing refresh token:
    #
    #   auth_token = OAuth2::AccessToken.from_hash(client,
    #       {:refresh_token => refresh_token, :expires_at => expires_at})
    #   auth_token = auth_token.refresh!
    #   session = GoogleDriveV0.login_with_oauth(auth_token.token)
    #
    # If your app is not a Web app, use "urn:ietf:wg:oauth:2.0:oob" as redirect_url. Then
    # authorization code is shown after authorization.
    #
    # See these documents for details:
    #
    # - https://github.com/intridea/oauth2
    # - http://code.google.com/apis/accounts/docs/OAuth2.html
    # - http://oauth.rubyforge.org/
    # - http://code.google.com/apis/accounts/docs/OAuth.html
    def self.login_with_oauth(access_token, proxy = nil)
      return Session.login_with_oauth(access_token, proxy)
    end

    # Restores session using return value of auth_tokens method of previous session.
    #
    # See GoogleDriveV0.login for description of parameter +proxy+.
    def self.restore_session(auth_tokens, proxy = nil)
      return Session.restore_session(auth_tokens, proxy)
    end
    
    # Restores GoogleDriveV0::Session from +path+ and returns it.
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
          :application_version => "0.3.11"
      )
      auth = client.authorization
      auth.client_id = client_id
      auth.client_secret = client_secret
      auth.scope =
          "https://www.googleapis.com/auth/drive " +
          "https://spreadsheets.google.com/feeds/ " +
          "https://docs.google.com/feeds/ " +
          "https://docs.googleusercontent.com/"
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

      return GoogleDriveV0.login_with_oauth(auth.access_token)

    end

end
