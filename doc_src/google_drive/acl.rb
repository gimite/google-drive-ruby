module GoogleDrive
    
    class Acl
        
        # Returns the number of entries.
        def size
        end
        
        # Returns GoogleDrive::AclEntry object at +index+.
        def [](index)
        end
        
        # Iterates over GoogleDrive::AclEntry objects.
        def each(&block)
          yield(entry)
        end
        
    end
    
end
