module GoogleSpreadsheet
    
    class Acl
        
        # Returns the number of entries.
        def size
        end
        
        # Returns GoogleSpreadsheet::AclEntry object at +index+.
        def [](index)
        end
        
        # Iterates over GoogleSpreadsheet::AclEntry objects.
        def each(&block)
          yield(entry)
        end
        
    end
    
end
