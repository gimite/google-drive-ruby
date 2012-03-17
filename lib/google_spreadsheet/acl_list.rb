# Author: Guy Boertje <https://github.com/guyboertje>
# Author: David R. Albrecht <https://github.com/eldavido>
# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_spreadsheet/acl"


module GoogleSpreadsheet
    
    # ACL (access control list) of a spreadsheet.
    #
    # Use GoogleSpreadsheet::Spreadsheet#acl to get GoogleSpreadsheet::Acl object.
    # See GoogleSpreadsheet::Spreadsheet#acl for usage example.
    #
    # This code is based on https://github.com/guyboertje/gdata-spreadsheet-ruby .
    class AclList
        
        include(Util)
        extend(Forwardable)
        
        def initialize(session, acls_feed_url) #:nodoc:
          @session = session
          @acls_feed_url = acls_feed_url
          header = {"GData-Version" => "3.0"}
          doc = @session.request(:get, @acls_feed_url, :header => header, :auth => :writely)
          @acls = doc.css("entry").map(){ |e| Acl.new(entry_to_params(e)) }
        end
        
        def_delegators(:@acls, :size, :[], :each)
        
        def push(acl)
          
          acl = Acl.new(acl) if acl.is_a?(Hash)
          
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml"}
          value_attr = acl.scope ? "value='#{h(acl.scope)}'" : ""
          xml = <<-EOS
            <entry
                xmlns='http://www.w3.org/2005/Atom'
                xmlns:gAcl='http://schemas.google.com/acl/2007'>
              <category scheme='http://schemas.google.com/g/2005#kind'
                  term='http://schemas.google.com/acl/2007#accessRule'/>
              <gAcl:role value='#{h(acl.role)}'/>
              <gAcl:scope type='#{h(acl.scope_type)}' #{value_attr}/>
            </entry>
          EOS
          doc = @session.request(
              :post, @acls_feed_url, :data => xml, :header => header, :auth => :writely)
          
          acl.params = entry_to_params(doc.root)
          @acls.push(acl)
          return acl
          
        end
        
        def delete(acl)
          header = {"GData-Version" => "3.0"}
          @session.request(:delete, acl.edit_url, :header => header, :auth => :writely)
          @acls.delete(acl)
        end
        
        def update_role(acl, role) #:nodoc:
          
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml"}
          value_attr = acl.scope ? "value='#{h(acl.scope)}'" : ""
          xml = <<-EOS
            <entry
                xmlns='http://www.w3.org/2005/Atom'
                xmlns:gAcl='http://schemas.google.com/acl/2007'
                xmlns:gd='http://schemas.google.com/g/2005'
                gd:etag='#{h(acl.etag)}'>
              <category
                  scheme='http://schemas.google.com/g/2005#kind'
                  term='http://schemas.google.com/acl/2007#accessRule'/>
              <gAcl:role value='#{h(role)}'/>
              <gAcl:scope type='#{h(acl.scope_type)}' #{value_attr}/>
            </entry>
          EOS
          doc = @session.request(
              :put, acl.edit_url, :data => xml, :header => header, :auth => :writely)
          
          acl.params = entry_to_params(doc.root)
          return acl
          
        end
        
        def inspect
          return "\#<%p %p>" % [self.class, @acls]
        end
        
      private
        
        def entry_to_params(entry)
          # TODO Support with-link roles.
          return {
            :acl_list => self,
            :scope_type => entry.css("gAcl|scope")[0]["type"],
            :scope => entry.css("gAcl|scope")[0]["value"],
            :role => entry.css("gAcl|role")[0]["value"],
            :title => entry.css("title").text,
            :edit_url => entry.css("link[rel='edit']")[0]["href"],
            :etag => entry["etag"],
          }
        end
        
    end
    
end
