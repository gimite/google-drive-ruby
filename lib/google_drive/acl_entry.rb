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

    # +params_or_api_permission+ is a Hash object with keys
    # +:type+, +:email_address+, +:domain+, +:role+ and +:allow_file_discovery+.
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

    # @api private
    attr_reader(:params)

    # @api private
    attr_accessor(:api_permission)

    # The role given to the scope. One of:
    # - "owner": The owner.
    # - "writer": With read/write access.
    # - "reader": With read-only access.
    def role
      @params ? @params[:role] : @api_permission.role
    end

    # Type of the scope. One of:
    #
    # - "user": a Google account specified by the email_address field.
    # - "group": a Google Group specified by the email_address field.
    # - "domain": a Google Apps domain specified by the domain field.
    # - "anyone": Publicly shared with all users.
    def type
      @params ? @params[:type] : @api_permission.type
    end

    alias scope_type type

    def additional_roles
      @params ? @params[:additionalRoles] : @api_permission.additional_roles
    end

    def id
      @params ? @params[:id] : @api_permission.id
    end

    # Email address of the user or the group.
    def email_address
      @params ? @params[:email_address] : @api_permission.email_address
    end

    # The Google Apps domain name.
    def domain
      @params ? @params[:domain] : @api_permission.domain
    end

    def value
      if @params
        case @params[:type]
        when 'user', 'group'
          @params[:email_address]
        when 'domain'
          @params[:domain]
        end
      else
        case @api_permission.type
        when 'user', 'group'
          @api_permission.email_address
        when 'domain'
          @api_permission.domain
        end
      end
    end

    alias scope value

    # If +false+, the file is shared only with people who know the link.
    # Only used for type "anyone".
    def allow_file_discovery
      @params ?
        @params[:allow_file_discovery] : @api_permission.allow_file_discovery
    end

    # If +true+, the file is shared only with people who know the link.
    # Only used for type "anyone".
    def with_link
      allow_file_discovery == false
    end

    alias with_key with_link

    # Changes the role of the scope.
    #
    # e.g.
    #   spreadsheet.acl[1].role = "writer"
    def role=(role)
      if @params
        @params[:role] = role
      else
        @api_permission.role = role
        @acl.update_role(self)
      end
    end

    def inspect
      case type
      when 'user', 'group'
        format(
          "\#<%p type=%p, email_address=%p, role=%p>",
          self.class, type, email_address, role
        )
      when 'domain'
        format(
          "\#<%p type=%p, domain=%p, role=%p>",
          self.class, type, domain, role
        )
      when 'anyone'
        format(
          "\#<%p type=%p, role=%p, allow_file_discovery=%p>",
          self.class, type, role, allow_file_discovery
        )
      else
        format("\#<%p type=%p, role=%p>", self.class, type, role)
      end
    end

    private

    # Normalizes the key to Symbol, and converts parameters in the old version.
    def convert_params(orig_params)
      new_params = {}
      value = nil
      orig_params.each do |k, v|
        k = k.to_s
        case k
        when 'scope_type'
          new_params[:type] = (v == 'default' ? 'anyone' : v)
        when 'scope'
          new_params[:value] = v
        when 'with_key', 'withLink'
          new_params[:allow_file_discovery] = !v
        when 'value'
          value = v
        else
          new_params[k.intern] = v
        end
      end

      if value
        case new_params[:type]
        when 'user', 'group'
          new_params[:email_address] = value
        when 'domain'
          new_params[:domain] = value
        end
      end

      new_params
    end
  end
end
