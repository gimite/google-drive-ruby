# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_drive_v0/error"


module GoogleDriveV0

    # Raised when GoogleDriveV0.login has failed.
    class AuthenticationError < GoogleDriveV0::Error

    end
    
end
