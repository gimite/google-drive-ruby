# Author: Phuogn Nguyen <https://github.com/phuongnd08>

module GoogleDrive

    # An acl with key entry of an ACL (access control list) of a spreadsheet.
    class AclEntryWithKey < AclEntry

        # +params+ is a Hash object with keys :role+.
        # See acl with key role for the document of the fields.
        def initialize(params)
          super(params)
        end

        def inspect
          "\#<%p role=%p>" %
              [self.class, @params[:role]]
        end

        def to_xml
          value_attr = scope ? "value='#{h(scope)}'" : ""
          #TODO: Use nokogiri xml builder
          xml = <<-EOS
          #{xml_open_tag}
              <category scheme='http://schemas.google.com/g/2005#kind'
                  term='http://schemas.google.com/acl/2007#accessRule'/>

              <gAcl:withKey key='[ACL KEY]'>
                <gAcl:role value='#{h(role)}'/>
              </gAcl:withKey>
              <gAcl:scope type='default' />
            </entry>
          EOS
        end

    end

end


