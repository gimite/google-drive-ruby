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

        PARAM_NAMES = [:acl, :scope_type, :scope, :with_key, :role, :title, :edit_url, :etag]  #:nodoc:

        # +params+ is a Hash object with keys +:scope_type+, +:scope+ and +:role+.
        # See scope_type and role for the document of the fields.
        def initialize(params)
          @params = {:role => "reader"}
          for name, value in params
            if !name.is_a?(Symbol)
              raise(ArgumentError, "Key must be Symbol, but is %p" % name)
            elsif !PARAM_NAMES.include?(name)
              raise(ArgumentError, "Invalid key: %p" % name)
            end
            @params[name] = value
          end
        end

        attr_accessor(:params)  #:nodoc:

        PARAM_NAMES.each() do |name|
          define_method(name) do
            return @params[name]
          end
        end

        # Changes the role of the scope.
        #
        # e.g.
        #   spreadsheet.acl[1].role = "writer"
        def role=(role)
          @params[:role] = role
          @params[:acl].update_role(self)
        end

        def inspect
          return "\#<%p scope_type=%p, scope=%p, with_key=%p, role=%p>" %
              [self.class, @params[:scope_type], @params[:scope], @params[:with_key], @params[:role]]
        end

        def to_xml()  #:nodoc:
          
          etag_attr = self.etag ? "gd:etag='#{h(self.etag)}'" : ""
          value_attr = self.scope ? "value='#{h(self.scope)}'" : ""
          if self.with_key
            role_tag = <<-EOS
                <gAcl:withKey key='[ACL KEY]'>
                  <gAcl:role value='#{h(self.role)}'/>
                </gAcl:withKey>
            EOS
          else
            role_tag = <<-EOS
              <gAcl:role value='#{h(self.role)}'/>
            EOS
          end
          
          return <<-EOS
            <entry
                xmlns='http://www.w3.org/2005/Atom'
                xmlns:gAcl='http://schemas.google.com/acl/2007'
                xmlns:gd='http://schemas.google.com/g/2005'
                #{etag_attr}>
              <category scheme='http://schemas.google.com/g/2005#kind'
                  term='http://schemas.google.com/acl/2007#accessRule'/>
              #{role_tag}
              <gAcl:scope type='#{h(self.scope_type)}' #{value_attr}/>
            </entry>
          EOS
          
        end

    end

end

