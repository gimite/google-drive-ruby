# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_drive_v1/error"


module GoogleDriveV1

    # Raised when GoogleDriveV1.login has failed.
    class AuthenticationError < GoogleDriveV1::Error

    end
    
end
