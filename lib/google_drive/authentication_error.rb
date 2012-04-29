# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_drive/error"


module GoogleDrive

    # Raised when GoogleDrive.login has failed.
    class AuthenticationError < GoogleDrive::Error

    end
    
end
