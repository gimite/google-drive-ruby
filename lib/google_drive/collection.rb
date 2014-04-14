# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_drive/util"
require "google_drive/error"
require "google_drive/spreadsheet"


module GoogleDrive

    # Use GoogleDrive::Session#root_collection, GoogleDrive::Collection#subcollections,
    # or GoogleDrive::Session#collection_by_url to get GoogleDrive::Collection object.
    class Collection < GoogleDrive::File

        include(Util)
        
        ROOT_URL = "#{DOCS_BASE_URL}/folder%3Aroot"  #:nodoc:

        alias collection_feed_url document_feed_url
        
        def contents_url
          if self.root?
            # The root collection doesn't have document feed.
            return concat_url(ROOT_URL, "/contents")
          else
            return self.document_feed_entry.css(
                "content[type='application/atom+xml;type=feed']")[0]["src"]
          end
        end
        
        # Title of the collection.
        #
        # Set <tt>params[:reload]</tt> to true to force reloading the title.
        def title(params = {})
          if self.root?
            # The root collection doesn't have document feed.
            return nil
          else
            return super
          end
        end

        def resource_id
          return self.root? ? nil : super
        end
        
        # Adds the given GoogleDrive::File to the collection.
        def add(file)
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml;charset=utf-8"}
          xml = <<-"EOS"
            <entry xmlns="http://www.w3.org/2005/Atom">
              <id>#{h(file.document_feed_url)}</id>
            </entry>
          EOS
          @session.request(
              :post, self.contents_url, :data => xml, :header => header, :auth => :writely)
          return nil
        end

        # Creates a sub-collection with given title. Returns GoogleDrive::Collection object.
        def create_subcollection(title)
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml;charset=utf-8"}
          xml = <<-EOS
            <entry xmlns="http://www.w3.org/2005/Atom">
              <category scheme="http://schemas.google.com/g/2005#kind"
                term="http://schemas.google.com/docs/2007#folder"/>
              <title>#{h(title)}</title>
            </entry>
          EOS
          doc = @session.request(
              :post, contents_url, :data => xml, :header => header, :auth => :writely)
          return @session.entry_element_to_file(doc)
        end

        # Removes the given GoogleDrive::File from the collection.
        def remove(file)
          url = to_v3_url("#{contents_url}/#{file.resource_id}")
          @session.request(:delete, url, :auth => :writely, :header => {"If-Match" => "*"})
        end

        # Returns true if this is a root collection
        def root?
          self.document_feed_url == ROOT_URL
        end

        # Returns all the files (including spreadsheets, documents, subcollections) in the collection.
        #
        # You can specify query parameters described at
        # https://developers.google.com/google-apps/documents-list/#getting_a_list_of_documents_and_files
        #
        # e.g.
        #
        #   # Gets all the files in collection, including subcollections.
        #   collection.files
        #   
        #   # Gets only files with title "hoge".
        #   collection.files("title" => "hoge", "title-exact" => "true")
        def files(params = {})
          return files_with_type(nil, params)
        end

        alias contents files

        # Returns all the spreadsheets in the collection.
        def spreadsheets(params = {})
          return files_with_type("spreadsheet", params)
        end
        
        # Returns all the Google Docs documents in the collection.
        def documents(params = {})
          return files_with_type("document", params)
        end
        
        # Returns all its subcollections.
        def subcollections(params = {})
          return files_with_type("folder", params)
        end
        
        # Returns a file (can be a spreadsheet, document, subcollection or other files) in the
        # collection which exactly matches +title+ as GoogleDrive::File.
        # Returns nil if not found. If multiple collections with the +title+ are found, returns
        # one of them.
        #
        # If given an Array, does a recursive subcollection traversal.
        def file_by_title(title)
          return file_by_title_with_type(title, nil)
        end
        
        # Returns its subcollection whose title exactly matches +title+ as GoogleDrive::Collection.
        # Returns nil if not found. If multiple collections with the +title+ are found, returns
        # one of them.
        #
        # If given an Array, does a recursive subcollection traversal.
        def subcollection_by_title(title)
          return file_by_title_with_type(title, "folder")
        end
        
      protected

        def file_by_title_with_type(title, type)
          if title.is_a?(Array)
            rel_path = title
            if rel_path.empty?
              return self
            else
              parent = subcollection_by_title(rel_path[0...-1])
              return parent && parent.file_by_title_with_type(rel_path[-1], type)
            end
          else
            return files_with_type(type, "title" => title, "title-exact" => "true")[0]
          end
        end
        
      private

        def files_with_type(type, params = {})
          contents_url = self.contents_url
          contents_url = concat_url(contents_url, "/-/#{type}") if type
          contents_url = concat_url(contents_url, "?" + encode_query(params))
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml;charset=utf-8"}
          doc = @session.request(:get, contents_url, :header => header, :auth => :writely)
          return doc.css("feed > entry").map(){ |e| @session.entry_element_to_file(e) }
        end
        
    end
    
end
