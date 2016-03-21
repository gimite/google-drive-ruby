# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require 'google_drive/response_code_error'

module GoogleDrive
  # Raised when GoogleDrive.login has failed.
  class AuthenticationError < GoogleDrive::ResponseCodeError
  end
end
