# Author: Guy Boertje <https://github.com/guyboertje>
# Author: David R. Albrecht <https://github.com/eldavido>
# Author: Hiroshi Ichikawa <http://gimite.net/>
# Author: Phuogn Nguyen <https://github.com/phuongnd08>
# The license of this source is "New BSD Licence"

module GoogleDrive

    # An entry of an ACL (access control list) of a spreadsheet.
    #
    # Use GoogleDrive::Acl#[] to get GoogleDrive::AclEntry object.
    #
    # This code is based on https://github.com/guyboertje/gdata-spreadsheet-ruby .
    class AclEntry

        include(Util)

        # +params+ is a Hash object with keys +:scope_type+, +:scope+ and +:role+.
        # See scope_type and role for the document of the fields.
        def initialize(api_permission, acl)
          @api_permission = api_permission
          @acl = acl
          delegate_api_methods(self, @api_permission)
        end

        attr_reader(:acl)
        attr_accessor(:api_permission) #:nodoc:

        def scope_type
          return self.type
        end

        def scope
          return self.value
        end

        def with_key
          return self.with_link
        end

        # Changes the role of the scope.
        #
        # e.g.
        #   spreadsheet.acl[1].role = "writer"
        def role=(role)
          @api_permission.role = role
          @acl.update_role(self)
        end

        def inspect
          return "\#<%p type=%p, name=%p, role=%p>" %
              [self.class, self.type, self.name, self.role]
        end

    end

end

