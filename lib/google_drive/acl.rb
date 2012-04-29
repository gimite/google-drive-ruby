# Author: Guy Boertje <https://github.com/guyboertje>
# Author: David R. Albrecht <https://github.com/eldavido>
# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_drive/acl_entry"


module GoogleDrive
    
    # ACL (access control list) of a spreadsheet.
    #
    # Use GoogleDrive::Spreadsheet#acl to get GoogleDrive::Acl object.
    # See GoogleDrive::Spreadsheet#acl for usage example.
    #
    # This code is based on https://github.com/guyboertje/gdata-spreadsheet-ruby .
    class Acl
        
        include(Util)
        extend(Forwardable)
        
        def initialize(session, acls_feed_url) #:nodoc:
          @session = session
          @acls_feed_url = acls_feed_url
          header = {"GData-Version" => "3.0"}
          doc = @session.request(:get, @acls_feed_url, :header => header, :auth => :writely)
          @acls = doc.css("entry").map(){ |e| AclEntry.new(entry_to_params(e)) }
        end
        
        def_delegators(:@acls, :size, :[], :each)
        
        # Adds a new entry. +entry+ is either a GoogleDrive::AclEntry or a Hash with keys
        # :scope_type, :scope and :role. See GoogleDrive::AclEntry#scope_type and
        # GoogleDrive::AclEntry#role for the document of the fields.
        #
        # NOTE: This sends email to the new people.
        #
        # e.g.
        #   spreadsheet.acl.push(
        #       {:scope_type => "user", :scope => "example2@gmail.com", :role => "reader"})
        #   spreadsheet.acl.push(
        #       {:scope_type => "user", :scope => "example3@gmail.com", :role => "writer"})
        def push(entry)
          
          entry = AclEntry.new(entry) if entry.is_a?(Hash)
          
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml"}
          value_attr = entry.scope ? "value='#{h(entry.scope)}'" : ""
          xml = <<-EOS
            <entry
                xmlns='http://www.w3.org/2005/Atom'
                xmlns:gAcl='http://schemas.google.com/acl/2007'>
              <category scheme='http://schemas.google.com/g/2005#kind'
                  term='http://schemas.google.com/acl/2007#accessRule'/>
              <gAcl:role value='#{h(entry.role)}'/>
              <gAcl:scope type='#{h(entry.scope_type)}' #{value_attr}/>
            </entry>
          EOS
          doc = @session.request(
              :post, @acls_feed_url, :data => xml, :header => header, :auth => :writely)
          
          entry.params = entry_to_params(doc.root)
          @acls.push(entry)
          return entry
          
        end
        
        # Deletes an ACL entry.
        #
        # e.g.
        #   spreadsheet.acl.delete(spreadsheet.acl[1])
        def delete(entry)
          header = {"GData-Version" => "3.0"}
          @session.request(:delete, entry.edit_url, :header => header, :auth => :writely)
          @acls.delete(entry)
        end
        
        def update_role(entry, role) #:nodoc:
          
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml"}
          value_attr = entry.scope ? "value='#{h(entry.scope)}'" : ""
          xml = <<-EOS
            <entry
                xmlns='http://www.w3.org/2005/Atom'
                xmlns:gAcl='http://schemas.google.com/acl/2007'
                xmlns:gd='http://schemas.google.com/g/2005'
                gd:etag='#{h(entry.etag)}'>
              <category
                  scheme='http://schemas.google.com/g/2005#kind'
                  term='http://schemas.google.com/acl/2007#accessRule'/>
              <gAcl:role value='#{h(role)}'/>
              <gAcl:scope type='#{h(entry.scope_type)}' #{value_attr}/>
            </entry>
          EOS
          doc = @session.request(
              :put, entry.edit_url, :data => xml, :header => header, :auth => :writely)
          
          entry.params = entry_to_params(doc.root)
          return entry
          
        end
        
        def inspect
          return "\#<%p %p>" % [self.class, @acls]
        end
        
      private
        
        def entry_to_params(entry)
          # TODO Support with-link roles.
          return {
            :acl => self,
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
