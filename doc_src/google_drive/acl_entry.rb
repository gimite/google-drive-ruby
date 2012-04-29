module GoogleDrive
    
    class AclEntry
        
        # Type of the scope. One of:
        #
        # - "user": scope is a user's email address.
        # - "group": scope is a Google Group email address.
        # - "domain": scope is a Google Apps domain.
        # - "default": Publicly shared with all users. scope is +nil+.
        attr_reader(:scope_type)
        
        # The scope. See scope_type.
        attr_reader(:scope)
        
        # The role given to the scope. One of:
        # - "owner": The owner.
        # - "writer": With read/write access.
        # - "reader": With read-only access.
        attr_reader(:role)
        
        # Title of the entry.
        attr_reader(:title)
        
        # Edit URL of the entry.
        attr_reader(:edit_url)
        
        # E-tag of the entry.
        attr_reader(:etag)
        
    end
    
end
