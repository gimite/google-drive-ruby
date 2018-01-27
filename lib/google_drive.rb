# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require 'json'
require 'googleauth'

require 'google_drive/session'

module GoogleDrive
  # Equivalent of either GoogleDrive::Session.from_credentials or
  # GoogleDrive::Session.from_access_token.
  def self.login_with_oauth(client_or_access_token, proxy = nil)
    Session.new(client_or_access_token, proxy)
  end

  # Alias of GoogleDrive::Session.from_config.
  def self.saved_session(
      config = ENV['HOME'] + '/.ruby_google_drive.token',
      proxy = nil,
      client_id = nil,
      client_secret = nil
  )
    if proxy
      raise(
        ArgumentError,
        'Specifying a proxy object is no longer supported. ' \
        'Set ENV["http_proxy"] instead.'
      )
    end

    Session.from_config(
      config, client_id: client_id, client_secret: client_secret
    )
  end
end
