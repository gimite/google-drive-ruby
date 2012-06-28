$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")
require "rubygems"
require "bundler/setup"

require "test/unit"
require "google_drive"
require "highline"


class TC_GoogleDrive < Test::Unit::TestCase
    
    # Random string is added to avoid conflict with existing file titles.
    PREFIX = "google-drive-ruby-test-4101301e303c-"
    
    @@session = nil
    
    def test_spreadsheet_online()
      session = get_session()
      
      ss_title = "#{PREFIX}spreadsheet"
      ss_copy_title = "#{PREFIX}spreadsheet-copy"
      
      # Removes test spreadsheets in the previous run in case the previous run failed.
      for ss in session.files("title" => ss_title, "title-exact" => true)
        delete_test_file(ss, true)
      end
      for ss in session.files("title" => ss_copy_title, "title-exact" => true)
        delete_test_file(ss, true)
      end
      
      ss = session.create_spreadsheet(ss_title)
      assert_equal(ss_title, ss.title)
      
      ws = ss.worksheets[0]
      assert_equal(ss.worksheets_feed_url, ws.spreadsheet.worksheets_feed_url)
      ws.title = "hoge"
      ws.max_rows = 20
      ws.max_cols = 10
      ws[1, 1] = "3"
      ws[1, 2] = "5"
      ws[1, 3] = "=A1+B1"
      ws[1, 4] = 13
      assert_equal(20, ws.max_rows)
      assert_equal(10, ws.max_cols)
      assert_equal(1, ws.num_rows)
      assert_equal(4, ws.num_cols)
      assert_equal("3", ws[1, 1])
      assert_equal("5", ws[1, 2])
      assert_equal("13", ws[1, 4])
      ws.save()
      
      ws.reload()
      assert_equal(20, ws.max_rows)
      assert_equal(10, ws.max_cols)
      assert_equal(1, ws.num_rows)
      assert_equal(4, ws.num_cols)
      assert_equal("3", ws[1, 1])
      assert_equal("5", ws[1, 2])
      assert_equal("8", ws[1, 3])
      assert_equal("13", ws[1, 4])
      if RUBY_VERSION >= "1.9.0"
        assert_equal(Encoding::UTF_8, ws[1, 1].encoding)
      end
      
      assert_equal("3\t5\t8\t13", ss.export_as_string("tsv", 0))

      ss2 = session.spreadsheet_by_key(ss.key)
      assert_equal(ss_title, ss2.title)
      assert_equal(ss.worksheets_feed_url, ss2.worksheets_feed_url)
      assert_equal(ss.human_url, ss2.human_url)
      assert_equal("hoge", ss2.worksheets[0].title)
      assert_equal("3", ss2.worksheets[0][1, 1])
      assert_equal("hoge", ss2.worksheet_by_title("hoge").title)
      assert_equal(nil, ss2.worksheet_by_title("foo"))
      if RUBY_VERSION >= "1.9.0"
        assert_equal(Encoding::UTF_8, ss2.title.encoding)
        assert_equal(Encoding::UTF_8, ss2.worksheets[0].title.encoding)
      end
      
      ss3 = session.spreadsheet_by_url("http://spreadsheets.google.com/ccc?key=#{ss.key}&hl=en")
      assert_equal(ss.worksheets_feed_url, ss3.worksheets_feed_url)
      ss4 = session.spreadsheet_by_url(ss.worksheets_feed_url)
      assert_equal(ss.worksheets_feed_url, ss4.worksheets_feed_url)
      
      assert_not_nil(session.spreadsheets.find(){ |s| s.title == ss_title })
      assert_not_nil(session.spreadsheets("title" => ss_title).
        find(){ |s| s.title == ss_title })
      
      ss5 = session.spreadsheet_by_title(ss_title)
      assert_not_nil(ss5)
      assert_equal(ss_title, ss5.title)
      
      ws2 = session.worksheet_by_url(ws.cells_feed_url)
      assert_equal(ws.cells_feed_url, ws2.cells_feed_url)
      assert_equal("hoge", ws2.title)
      
      ss_copy = ss.duplicate(ss_copy_title)
      assert_not_nil(session.spreadsheets("title" => ss_copy_title).
        find(){ |s| s.title == ss_copy_title })
      assert_equal("3", ss_copy.worksheets[0][1, 1])
      
      # Access via GoogleDrive::Worksheet#list.
      ws.list.keys = ["x", "y"]
      ws.list.push({"x" => "1", "y" => "2"})
      ws.list.push({"x" => "3", "y" => "4"})
      assert_equal(["x", "y"], ws.list.keys)
      assert_equal(2, ws.list.size)
      assert_equal("1", ws.list[0]["x"])
      assert_equal("2", ws.list[0]["y"])
      assert_equal("3", ws.list[1]["x"])
      assert_equal("4", ws.list[1]["y"])
      assert_equal("x", ws[1, 1])
      assert_equal("y", ws[1, 2])
      assert_equal("1", ws[2, 1])
      assert_equal("2", ws[2, 2])
      assert_equal("3", ws[3, 1])
      assert_equal("4", ws[3, 2])
      ws.list[0]["x"] = "5"
      ws.list[1] = {"x" => "6", "y" => "7"}
      assert_equal("5", ws.list[0]["x"])
      assert_equal("2", ws.list[0]["y"])
      assert_equal("6", ws.list[1]["x"])
      assert_equal("7", ws.list[1]["y"])
      
      assert_equal([2, 1], ws.cell_name_to_row_col("A2"))
      assert_equal([2, 26], ws.cell_name_to_row_col("Z2"))
      assert_equal([2, 27], ws.cell_name_to_row_col("AA2"))
      assert_equal([2, 28], ws.cell_name_to_row_col("AB2"))
      
      # Makes sure we can access cells by name as well as by (row, col) pairs.
      assert_equal(ws[2, 1], ws["A2"])
      assert_equal(ws.input_value(2, 1), ws.input_value("A2"))

      # Makes sure we can write to a cell by name.
      ws[2, 1] = "5"
      ws["A2"] = "555"
      assert_equal("555", ws[2, 1])

      # Test of update_cells().
      ws.update_cells(1, 1, [["1", "2"], ["3", "4"]])
      assert_equal("1", ws[1, 1])
      assert_equal("4", ws[2, 2])
      ws.update_cells(2, 1, [["5", "6"], ["7", "8"]])
      assert_equal("1", ws[1, 1])
      assert_equal("6", ws[2, 2])
      assert_equal("7", ws[3, 1])
      
      delete_test_file(ss)
      assert_nil(session.spreadsheets("title" => ss_title).
        find(){ |s| s.title == ss_title })
      delete_test_file(ss_copy, true)
      assert_nil(session.spreadsheets("title" => ss_copy_title).
        find(){ |s| s.title == ss_copy_title })
      delete_test_file(ss, true)
      
    end
    
    # Tests various manipulations with files and collections.
    def test_collection_and_file_online()
      
      session = get_session()

      # Gets root collection.
      root = session.root_collection
      assert(root.root?)
      assert_equal("root", root.resource_id)

      test_collection_name = "#{PREFIX}collection"
      test_file_name = "#{PREFIX}file.txt"

      # Removes test files/collections in the previous run in case the previous run failed.
      for file in root.files("title" => test_file_name, "title-exact" => true)
        delete_test_file(file, true)
      end
      for collection in root.subcollections(
          "title" => test_collection_name, "title-exact" => true)
        delete_test_file(collection, true)
      end

      collection = root.subcollection_by_title(test_collection_name)
      assert_nil(collection)

      # Creates collection.
      collection = root.create_subcollection(test_collection_name)
      assert_instance_of(GoogleDrive::Collection, collection)
      assert_equal(test_collection_name, collection.title)
      refute(collection.root?)
      refute_empty(collection.resource_id)
      refute_nil(root.subcollection_by_title(test_collection_name))

      # Uploads a test file.
      test_file_path = File.join(File.dirname(__FILE__), "test_file.txt")
      file = session.upload_from_file(test_file_path, test_file_name, :convert => false)
      assert_instance_of(GoogleDrive::File, file)
      assert_equal(test_file_name, file.title)
      assert_equal(File.read(test_file_path), file.download_to_string())

      # Checks if file exists in root.
      files = root.files("title" => test_file_name, "title-exact" => true)
      assert_equal(1, files.size)
      assert_equal(test_file_name, files[0].title)

      # Moves file to collection.
      collection.add(file)
      root.remove(file)

      # Checks if file exists in collection.
      files = root.files("title" => test_file_name, "title-exact" => true)
      assert_equal(0, files.size)
      files = collection.files("title" => test_file_name, "title-exact" => true)
      assert_equal(1, files.size)
      assert_equal(test_file_name, files[0].title)

      # Deletes file.
      delete_test_file(file, true)
      # Ensure the files is removed from collection.
      files = collection.files("title" => test_file_name, "title-exact" => true)
      assert_equal(0, files.size)
      # Ensure the file is removed from Google Drive.
      refute(session.files().any?{|a| a.title == test_collection_name})

      # Deletes collection.
      delete_test_file(collection, true)
      # Ensure the collection is removed from root.
      assert_nil(root.subcollection_by_title(test_collection_name))
      # Ensure the collection is removed from Google Drive.
      refute(session.files(showfolders: true).any?{|a| a.title == test_collection_name})
    end
    
    def test_collection_offline()
      
      browser_url =
          "https://docs.google.com/?tab=mo&authuser=0#folders/" +
          "0B9GfDpQ2pBVUODNmOGE0NjIzMWU3ZC00NmUyLTk5NzEtYaFkZjY1MjAyxjMc"
 	    collection_feed_url =
          "https://docs.google.com/feeds/default/private/full/folder%3A" +
          "0B9GfDpQ2pBVUODNmOGE0NjIzMWU3ZC00NmUyLTk5NzEtYaFkZjY1MjAyxjMc"
      session = GoogleDrive::Session.new_dummy()
      
      collection = session.collection_by_url(browser_url)
      assert_equal(collection_feed_url, collection.collection_feed_url)
      
      collection = session.collection_by_url(collection_feed_url)
      assert_equal(collection_feed_url, collection.collection_feed_url)

    end

    def get_session()
      if !@@session
        puts("This test will create files/spreadsheets/collections with your account,")
        puts("read/write them and finally delete them (if everything succeeds).")
        account_path = File.join(File.dirname(__FILE__), "account.yaml")
        if File.exist?(account_path)
          account = YAML.load_file(account_path)
        else
          account = {}
        end
        if account["use_saved_session"]
          @@session = GoogleDrive.saved_session
        elsif account["mail"] && account["password"]
          @@session = GoogleDrive.login(account["mail"], account["password"])
        else
          highline = HighLine.new()
          mail = highline.ask("Mail: ")
          password = highline.ask("Password: "){ |q| q.echo = false }
          @@session = GoogleDrive.login(mail, password)
        end
      end
      return @@session
    end
    
    # Wrapper of GoogleDrive::File#delete which makes sure not to delete non-test files.
    def delete_test_file(file, permanent = false)
      esc_prefix = Regexp.escape(PREFIX)
      if file.title =~ Regexp.new("\\A#{esc_prefix}")
        file.delete(permanent)
      else
        raise("Trying to delete non-test file: %p" % file)
      end
    end
    
end
