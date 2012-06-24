# encoding: UTF-8

$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")
require "rubygems"
require "bundler/setup"

require "test/unit"
require "google_drive"
require "highline"


class TC_GoogleDrive < Test::Unit::TestCase

    def get_live_session
      account_path = File.join(File.dirname(__FILE__), "account.yaml")
      if File.exist?(account_path)
        file_content = File.read account_path
        account = YAML.load ERB.new(file_content).result
      else
        account = {}
      end
      if account["use_saved_session"]
        session = GoogleDrive.saved_session
      elsif account["mail"] && account["password"]
        session = GoogleDrive.login(account["mail"], account["password"])
      else
        highline = HighLine.new()
        mail = highline.ask("Mail: ")
        password = highline.ask("Password: "){ |q| q.echo = false }
        session = GoogleDrive.login(mail, password)
      end
      session
    end
    
    def test_all()
      puts("This test will create spreadsheets with your account, read/write them")
      puts("and finally delete them (if everything goes well).")
      session = get_live_session

      ss_title = "google-spreadsheet-ruby test " + Time.now.strftime("%Y-%m-%d-%H-%M-%S")
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
      
      ss_copy_title = "google-spreadsheet-ruby test copy " + Time.now.strftime("%Y-%m-%d-%H-%M-%S")
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
      
      ss.delete()
      assert_nil(session.spreadsheets("title" => ss_title).
        find(){ |s| s.title == ss_title })
      ss_copy.delete(true)
      assert_nil(session.spreadsheets("title" => ss_copy_title).
        find(){ |s| s.title == ss_copy_title })
      ss.delete(true)
      
    end
    

    def test_collection()
      
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

    # test various manipulations with files and collections
    def test_collections_and_files()
      session = get_live_session

      # get root collection
      root = session.root_collection
      assert root.root?
      assert_equal 'root', root.resource_id

      test_subcol_name = 'Google Drive test subcollection one2'
      test_file_name = 'Google Drive test file un1que.txt'

      # remove test files from root
      existing_files = root.files 'title' => test_file_name,
                                  'title-exact' => true
      # double check the title so we do not accudently delete other non-test files
      existing_files.select! {|s| s.title == test_file_name }
      existing_files.each do |s|
        s.delete true
      end
      
      # remove test subcollections if exist
      existing_subcollections = root.subcollections 'title' => test_subcol_name,
                                                    'title-exact' => true
      # double check the title so we do not accudently delete other non-test collections
      existing_subcollections.select! {|s| s.title == test_subcol_name }
      existing_subcollections.each do |s|
        s.delete true
      end

      subcollection = root.subcollection_by_title test_subcol_name
      assert_nil subcollection

      # create subcollection
      subcollection = root.create_subcollection test_subcol_name
      assert_instance_of GoogleDrive::Collection, subcollection
      assert_equal test_subcol_name, subcollection.title
      refute subcollection.root?
      refute_empty subcollection.resource_id
      refute_nil root.subcollection_by_title test_subcol_name

      # upload a test file
      test_file_path = File.join File.dirname(__FILE__), 'data', test_file_name
      file = session.upload_from_file test_file_path
      assert_instance_of GoogleDrive::File, file
      assert_equal test_file_name, file.title

      # check if file exists in root
      files = root.files 'title' => test_file_name, 'title-exact' => true
      assert_equal 1, files.size
      file_check = files[0]
      assert_equal test_file_name, file_check.title

      # move file to subcollection
      subcollection.add file
      root.remove_from_collection file

      # check if file exists in subcollection
      files = root.files 'title' => test_file_name, 'title-exact' => true
      assert_equal 0, files.size
      files = subcollection.files 'title' => test_file_name, 'title-exact' => true
      assert_equal 1, files.size
      assert_equal test_file_name, file_check.title

      # delete file
      file.delete true
      files = subcollection.files 'title' => test_file_name, 'title-exact' => true
      assert_equal 0, files.size

      # delete subcollection
      subcollection.delete true
      assert_nil root.subcollection_by_title test_subcol_name
    end
end
