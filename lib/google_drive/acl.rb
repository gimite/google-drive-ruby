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

        def initialize(session, file) #:nodoc:
          @session = session
          @file = file
          api_result = @session.execute!(
              :api_method => @session.drive.permissions.list,
              :parameters => { "fileId" => @file.id })
          @entries = api_result.data.items.map(){ |i| AclEntry.new(i, self) }
        end

        def_delegators(:@entries, :size, :[], :each)

        # Adds a new entry. +entry+ is either a GoogleDrive::AclEntry or a Hash with keys
        # :scope_type, :scope and :role. See GoogleDrive::AclEntry#scope_type and
        # GoogleDrive::AclEntry#role for the document of the fields.
        #
        # NOTE: This sends email to the new people.
        #
        # e.g.
        #   # A specific user can read or write.
        #   spreadsheet.acl.push(
        #       {:type => "user", :value => "example2@gmail.com", :role => "reader"})
        #   spreadsheet.acl.push(
        #       {:type => "user", :value => "example3@gmail.com", :role => "writer"})
        #   # Publish on the Web.
        #   spreadsheet.acl.push(
        #       {:type => "anyone", :role => "reader"})
        #   # Anyone who knows the link can read.
        #   spreadsheet.acl.push(
        #       {:type => "anyone", :withLink => true, :role => "reader"})
        #
        # See here for parameter detais:
        # https://developers.google.com/drive/v2/reference/permissions/insert
        def push(params_or_entry)
          entry = params_or_entry.is_a?(AclEntry) ? params_or_entry : AclEntry.new(params_or_entry)
          new_permission = @session.drive.permissions.insert.request_schema.new(entry.params)
          api_result = @session.execute!(
              :api_method => @session.drive.permissions.insert,
              :body_object => new_permission,
              :parameters => { "fileId" => @file.id })
          new_entry = AclEntry.new(api_result.data, self)
          @entries.push(new_entry)
          return new_entry
        end

        # Deletes an ACL entry.
        #
        # e.g.
        #   spreadsheet.acl.delete(spreadsheet.acl[1])
        def delete(entry)
          @session.execute!(
              :api_method => @session.drive.permissions.delete,
              :parameters => {
                  "fileId" => @file.id,
                  "permissionId" => entry.id,
                })
          @entries.delete(entry)
        end

        def update_role(entry) #:nodoc:
          api_result = @session.execute!(
              :api_method => @session.drive.permissions.update,
              :body_object => entry.api_permission,
              :parameters => {
                  "fileId" => @file.id,
                  "permissionId" => entry.id,
              })
          entry.api_permission = api_result.data
          return entry
        end

        def inspect
          return "\#<%p %p>" % [self.class, @entries]
        end

    end

end
