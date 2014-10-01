# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "json"
require "google/api_client"

require "google_drive/session"


module GoogleDrive

    # Authenticates with given OAuth1 or OAuth2 token.
    #
    # +access_token+ can be either OAuth2 access_token string, OAuth2::AccessToken or OAuth::AccessToken.
    #
    # +proxy+ can be nil or return value of Net::HTTP.Proxy. If +proxy+ is specified, all
    # HTTP access in the session uses the proxy. If +proxy+ is nil, it uses the proxy
    # specified by http_proxy environment variable if available. Otherwise it performs direct
    # access.
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
    #   session = GoogleDrive.login_with_oauth(auth_token.token)
    #
    # Or, from existing refresh token:
    #
    #   auth_token = OAuth2::AccessToken.from_hash(client,
    #       {:refresh_token => refresh_token, :expires_at => expires_at})
    #   auth_token = auth_token.refresh!
    #   session = GoogleDrive.login_with_oauth(auth_token.token)
    #
    # If your app is not a Web app, use "urn:ietf:wg:oauth:2.0:oob" as redirect_url. Then
    # authorization code is shown after authorization.
    #
    # OAuth1 code example:
    #
    # 1) First generate OAuth consumer object with key and secret for your site by registering site
    #    with Google.
    #   @consumer = OAuth::Consumer.new( "key","secret", {:site=>"https://agree2"})
    # 2) Request token with OAuth.
    #   @request_token = @consumer.get_request_token
    #   session[:request_token] = @request_token
    #   redirect_to @request_token.authorize_url
    # 3) Create an oauth access token.
    #   @oauth_access_token = @request_token.get_access_token
    #   @access_token = OAuth::AccessToken.new(
    #       @consumer, @oauth_access_token.token, @oauth_access_token.secret)
    #
    # See these documents for details:
    #
    # - https://github.com/intridea/oauth2
    # - http://code.google.com/apis/accounts/docs/OAuth2.html
    # - http://oauth.rubyforge.org/
    # - http://code.google.com/apis/accounts/docs/OAuth.html
    def self.login_with_oauth(client_or_access_token, proxy = nil)
      return Session.new(client_or_access_token, proxy)
    end

    # Restores GoogleDrive::Session from +path+ and returns it.
    # If +path+ doesn't exist or authentication has failed, prompts mail and password on console,
    # authenticates with them, stores the session to +path+ and returns it.
    #
    # See login for description of parameter +proxy+.
    #
    # This method requires Highline library: http://rubyforge.org/projects/highline/
    def self.saved_session(
        path = ENV["HOME"] + "/.ruby_google_drive.token", proxy = nil, client_id = nil, client_secret = nil)

      if !client_id && !client_secret
        client_id = "452925651630-egr1f18o96acjjvphpbbd1qlsevkho1d.apps.googleusercontent.com"
        client_secret = "1U3-Krii5x1oLPrwD5zgn-ry"
      elsif !client_id || !client_secret
        raise(ArgumentError, "client_id and client_secret must be both specified or both omitted")
      end

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

        auth.access_token = token_data["access_token"]
        auth.refresh_token = token_data["refresh_token"]
        auth.expires_in = token_data["expires_in"]
        auth.issued_at = Time.iso8601(token_data["issued_at"])
        auth.fetch_access_token!()

      else

        $stderr.print("\n1. Open this page:\n%s\n\n" % auth.authorization_uri)
        $stderr.print("2. Enter the authorization code shown in the page: ")
        auth.code = $stdin.gets().chomp()
        auth.fetch_access_token!()
        token_data = {
            "access_token" => auth.access_token,
            "refresh_token" => auth.refresh_token,
            "expires_in" => auth.expires_in,
            "issued_at" => auth.issued_at.iso8601,
        }
        open(path, "w", 0600) do |f|
          f.puts(JSON.dump(token_data))
        end

      end

      return GoogleDrive.login_with_oauth(client)

    end
    
end
