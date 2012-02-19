# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_spreadsheet/error"


module GoogleSpreadsheet

    # Raised when GoogleSpreadsheet.login has failed.
    class AuthenticationError < GoogleSpreadsheet::Error

    end
    
end
