# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "forwardable"

require "google_drive/util"
require "google_drive/error"


module GoogleDrive

    # Hash-like object returned by GoogleDrive::List#[].
    class ListRow
        
        include(Enumerable)
        extend(Forwardable)
        
        def_delegators(:to_hash,
            :keys, :values, :each_key, :each_value, :each, :each_pair, :hash,
            :assoc, :fetch, :flatten, :key, :invert, :size, :length, :rassoc,
            :merge, :reject, :select, :sort, :to_a, :values_at)
        
        def initialize(list, index) #:nodoc:
          @list = list
          @index = index
        end
        
        def [](key)
          return @list.get(@index, key)
        end
        
        def numeric_value(key)
          return @list.numeric_value(@index, key)
        end
        
        def []=(key, value)
          @list.set(@index, key, value)
        end
        
        def has_key?(key)
          return @list.keys.include?(key)
        end
        
        alias include? has_key?
        alias key? has_key?
        alias member? has_key?
        
        def update(hash)
          for k, v in hash
            self[k] = v
          end
        end
        
        alias merge! update
        
        def replace(hash)
          clear()
          update(hash)
        end
        
        def clear()
          for key in @list.keys
            self[key] = ""
          end
        end
        
        def to_hash()
          result = {}
          for key in @list.keys
            result[key] = self[key]
          end
          return result
        end
        
        def ==(other)
          return self.class == other.class && self.to_hash() == other.to_hash()
        end
        
        alias === ==
        alias eql? ==
        
        def inspect
          return "\#<%p %p>" % [self.class, to_hash()]
        end
        
    end
    
end
