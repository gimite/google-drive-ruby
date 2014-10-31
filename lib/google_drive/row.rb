# Author: Guy Boertje <https://github.com/guyboertje>
# The license of this source is "New BSD Licence"

require "google_drive/util"
require "google_drive/error"

module GoogleDrive

  # Provides access to cells using column names.
  # Use GoogleDrive::Worksheet#list to get GoogleDrive::List object.
  #--
  # This is implemented as wrapper of GoogleDrive::Worksheet i.e. using cells
  # feed, not list feed. In this way, we can easily provide consistent API as
  # GoogleDrive::Worksheet using save()/reload().
  class Row

  end
end
