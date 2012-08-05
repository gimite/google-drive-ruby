# Author: Guy Boertje <https://github.com/guyboertje>
# Author: David R. Albrecht <https://github.com/eldavido>
# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

# acl.rb, derived from https://github.com/guyboertje/gdata-spreadsheet-ruby/blob/master/lib/document.rb
# more frankensteining of the original library

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
            if !PARAM_NAMES.include?(name)
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
          @params[:acl].update_role(self, role)
        end

        def inspect
          return "\#<%p scope_type=%p, scope=%p, role=%p>" %
              [self.class, @params[:scope_type], @params[:scope], @params[:role]]
        end

        def xml_open_tag
          if etag
            %{
              <entry
                xmlns='http://www.w3.org/2005/Atom'
                xmlns:gAcl='http://schemas.google.com/acl/2007'
                xmlns:gd='http://schemas.google.com/g/2005'
                gd:etag='#{h(entry.etag)}'>
            }
          else
            %{
              <entry
                  xmlns='http://www.w3.org/2005/Atom'
                  xmlns:gAcl='http://schemas.google.com/acl/2007'>
            }
          end

        end

        def to_xml
          value_attr = scope ? "value='#{h(scope)}'" : ""
          xml = <<-EOS
            #{xml_open_tag}
              <category scheme='http://schemas.google.com/g/2005#kind'
                  term='http://schemas.google.com/acl/2007#accessRule'/>
              <gAcl:role value='#{h(role)}'/>
              <gAcl:scope type='#{h(scope_type)}' #{value_attr}/>
            </entry>
          EOS
        end

      class << self
        def load(params)
          if params[:with_key]
            AclEntryWithKey.new(params)
          else
            AclEntry.new(params)
          end
        end
      end
    end

end

