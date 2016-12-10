module GoogleDrive
  # A simple credentials class using an existing OAuth2 access_token.
  #
  # Based on:
  # https://github.com/google/google-api-ruby-client/issues/296
  #
  # @api private
  class AccessTokenCredentials
    attr_reader :access_token

    def initialize(access_token)
      @access_token = access_token
    end

    def apply!(headers)
      headers['Authorization'] = "Bearer #{@access_token}"
    end
  end
end
