# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_drive/util"
require "google_drive/error"
require "google_drive/list_row"


module GoogleDrive

    # Provides access to cells using column names.
    # Use GoogleDrive::Worksheet#list to get GoogleDrive::List object.
    #--
    # This is implemented as wrapper of GoogleDrive::Worksheet i.e. using cells
    # feed, not list feed. In this way, we can easily provide consistent API as
    # GoogleDrive::Worksheet using save()/reload().
    class List
        
        include(Enumerable)
        
        def initialize(worksheet) #:nodoc:
          @worksheet = worksheet
        end
        
        # Number of non-empty rows in the worksheet excluding the first row.
        def size
          return @worksheet.num_rows - 1
        end
        
        # Returns Hash-like object (GoogleDrive::ListRow) for the row with the
        # index. Keys of the object are colum names (the first row).
        # The second row has index 0.
        #
        # Note that updates to the returned object are not sent to the server until
        # you call GoogleDrive::Worksheet#save().
        def [](index)
          return ListRow.new(self, index)
        end
        
        # Updates the row with the index with the given Hash object.
        # Keys of +hash+ are colum names (the first row).
        # The second row has index 0.
        #
        # Note that update is not sent to the server until
        # you call GoogleDrive::Worksheet#save().
        def []=(index, hash)
          self[index].replace(hash)
        end
        
        # Iterates over Hash-like object (GoogleDrive::ListRow) for each row
        # (except for the first row).
        # Keys of the object are colum names (the first row).
        def each(&block)
          for i in 0...self.size
            yield(self[i])
          end
        end
        
        # Column names i.e. the contents of the first row.
        # Duplicates are removed.
        def keys
          return (1..@worksheet.num_cols).map(){ |i| @worksheet[1, i] }.uniq()
        end
        
        # Updates column names i.e. the contents of the first row.
        #
        # Note that update is not sent to the server until
        # you call GoogleDrive::Worksheet#save().
        def keys=(ary)
          for i in 1..ary.size
            @worksheet[1, i] = ary[i - 1]
          end
          for i in (ary.size + 1)..@worksheet.num_cols
            @worksheet[1, i] = ""
          end
        end
        
        # Adds a new row to the bottom.
        # Keys of +hash+ are colum names (the first row).
        # Returns GoogleDrive::ListRow for the new row.
        #
        # Note that update is not sent to the server until
        # you call GoogleDrive::Worksheet#save().
        def push(hash)
          row = self[self.size]
          row.update(hash)
          return row
        end
        
        # Returns all rows (except for the first row) as Array of Hash.
        # Keys of Hash objects are colum names (the first row).
        def to_hash_array()
          return self.map(){ |r| r.to_hash() }
        end
        
        def get(index, key) #:nodoc:
          return @worksheet[index + 2, key_to_col(key)]
        end
        
        def numeric_value(index, key) #:nodoc:
          return @worksheet.numeric_value(index + 2, key_to_col(key))
        end
        
        def set(index, key, value) #:nodoc:
          @worksheet[index + 2, key_to_col(key)] = value
        end
        
      private
        
        def key_to_col(key)
          key = key.to_s()
          col = (1..@worksheet.num_cols).find(){ |c| @worksheet[1, c] == key }
          raise(GoogleDrive::Error, "Column doesn't exist: %p" % key) if !col
          return col
        end
        
    end
    
end
