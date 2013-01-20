# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_drive/session"


module GoogleDrive

    # Authenticates with given +mail+ and +password+, and returns GoogleDrive::Session
    # if succeeds. Raises GoogleDrive::AuthenticationError if fails.
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
    def self.login_with_oauth(access_token, proxy = nil)
      return Session.login_with_oauth(access_token, proxy)
    end

    # Restores session using return value of auth_tokens method of previous session.
    #
    # See GoogleDrive.login for description of parameter +proxy+.
    def self.restore_session(auth_tokens, proxy = nil)
      return Session.restore_session(auth_tokens, proxy)
    end
    
    # Restores GoogleDrive::Session from +path+ and returns it.
    # If +path+ doesn't exist or authentication has failed, prompts mail and password on console,
    # authenticates with them, stores the session to +path+ and returns it.
    #
    # See login for description of parameter +proxy+.
    #
    # This method requires Highline library: http://rubyforge.org/projects/highline/
    def self.saved_session(path = ENV["HOME"] + "/.ruby_google_drive.token", proxy = nil)
      tokens = {}
      if ::File.exist?(path)
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
            "GoogleDrive.saved_session requires Highline library.\n" +
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
    
end
