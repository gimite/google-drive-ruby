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

        # +params_or_api_permission+ is a Hash object with keys +:type+, +:value+, +:role+ and +:withLink+.
        # See GoogleDrive::Acl#push for description of the parameters.
        def initialize(params_or_api_permission, acl = nil)
          @acl = acl
          if acl
            @api_permission = params_or_api_permission
            @params = nil
            delegate_api_methods(self, @api_permission)
          else
            @api_permission = nil
            @params = convert_params(params_or_api_permission)
          end
        end

        attr_reader(:acl)
        attr_reader(:params) #:nodoc:
        attr_accessor(:api_permission) #:nodoc:

        # The role given to the scope. One of:
        # - "owner": The owner.
        # - "writer": With read/write access.
        # - "reader": With read-only access.
        def role
          return @params ? @params["role"] : @api_permission.role
        end

        # Type of the scope. One of:
        #
        # - "user": value is a user's email address.
        # - "group": value is a Google Group email address.
        # - "domain": value is a Google Apps domain.
        # - "anyone": Publicly shared with all users. value is +nil+.
        def type
          return @params ? @params["type"] : @api_permission.type
        end

        alias scope_type type

        def additional_roles
          return @params ? @params["additionalRoles"] : @api_permission.additional_roles
        end

        def id
          return @params ? @params["id"] : @api_permission.id
        end

        # The value of the scope. See type.
        def value
          return @params ? @params["value"] : @api_permission.value
        end

        alias scope value

        # If +true+, the file is shared only with people who know the link.
        def with_link
          return @params ? @params["withLink"] : @api_permission.with_link
        end

        alias with_key with_link

        # Changes the role of the scope.
        #
        # e.g.
        #   spreadsheet.acl[1].role = "writer"
        def role=(role)
          if @params
            @params["role"] = role
          else
            @api_permission.role = role
            @acl.update_role(self)
          end
        end

        def inspect
          return "\#<%p type=%p, name=%p, role=%p>" %
              [self.class, self.type, self.name, self.role]
        end

      private

        # Normalizes the key to String, and converts parameters in the old version.
        def convert_params(orig_params)
          new_params = {}
          for k, v in orig_params
            k = k.to_s()
            case k
              when "scope_type"
                new_params["type"] = (v == "default" ? "anyone" : v)
              when "scope"
                new_params["value"] = v
              when "with_key"
                new_params["withLink"] = v
              else
                new_params[k] = v
            end
          end
          return new_params
        end

    end

end

