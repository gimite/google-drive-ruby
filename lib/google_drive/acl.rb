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
        #   # A specific user can read or write.
        #   spreadsheet.acl.push(
        #       {:scope_type => "user", :scope => "example2@gmail.com", :role => "reader"})
        #   spreadsheet.acl.push(
        #       {:scope_type => "user", :scope => "example3@gmail.com", :role => "writer"})
        #   # Publish on the Web.
        #   spreadsheet.acl.push(
        #       {:scope_type => "default", :role => "reader"})
        #   # Anyone who knows the link can read.
        #   spreadsheet.acl.push(
        #       {:scope_type => "default", :with_key => true, :role => "reader"})
        def push(entry)

          entry = AclEntry.new(entry) if entry.is_a?(Hash)

          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml;charset=utf-8"}
          doc = @session.request(
              :post, @acls_feed_url, :data => entry.to_xml(), :header => header, :auth => :writely)

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

        def update_role(entry) #:nodoc:

          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml;charset=utf-8"}
          doc = @session.request(
              :put, entry.edit_url, :data => entry.to_xml(), :header => header, :auth => :writely)

          entry.params = entry_to_params(doc.root)
          return entry

        end

        def inspect
          return "\#<%p %p>" % [self.class, @acls]
        end

      private

        def entry_to_params(entry)
          
          if !entry.css("gAcl|withKey").empty?
            with_key = true
            role = entry.css("gAcl|withKey gAcl|role")[0]["value"]
          else
            with_key = false
            role = entry.css("gAcl|role")[0]["value"]
          end

          return {
            :acl => self,
            :scope_type => entry.css("gAcl|scope")[0]["type"],
            :scope => entry.css("gAcl|scope")[0]["value"],
            :with_key => with_key,
            :role => role,
            :title => entry.css("title").text,
            :edit_url => entry.css("link[rel='edit']")[0]["href"],
            :etag => entry["etag"],
          }
          
        end

    end

end
