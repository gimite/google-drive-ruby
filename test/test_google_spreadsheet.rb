$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")
require "rubygems"
require "bundler/setup"

require "test/unit"
require "google_spreadsheet"
require "highline"


class TC_GoogleSpreadsheet < Test::Unit::TestCase
    
    def test_all()
      
      puts("This test will create spreadsheets with your account, read/write them")
      puts("and finally delete them (if everything goes well).")
      account_path = File.join(File.dirname(__FILE__), "account.yaml")
      if File.exist?(account_path)
        account = YAML.load_file(account_path)
      else
        account = {}
      end
      if account["use_saved_session"]
        session = GoogleSpreadsheet.saved_session
      elsif account["mail"] && account["password"]
        session = GoogleSpreadsheet.login(account["mail"], account["password"])
      else
        highline = HighLine.new()
        mail = highline.ask("Mail: ")
        password = highline.ask("Password: "){ |q| q.echo = false }
        session = GoogleSpreadsheet.login(mail, password)
      end
      
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
      assert_equal(20, ws.max_rows)
      assert_equal(10, ws.max_cols)
      assert_equal(1, ws.num_rows)
      assert_equal(3, ws.num_cols)
      assert_equal("3", ws[1, 1])
      assert_equal("5", ws[1, 2])
      ws.save()
      
      ws.reload()
      assert_equal(20, ws.max_rows)
      assert_equal(10, ws.max_cols)
      assert_equal(1, ws.num_rows)
      assert_equal(3, ws.num_cols)
      assert_equal("3", ws[1, 1])
      assert_equal("5", ws[1, 2])
      assert_equal("8", ws[1, 3])
      if RUBY_VERSION >= "1.9.0"
        assert_equal(Encoding::UTF_8, ws[1, 1].encoding)
      end
      
      assert_equal("3\t5\t8", ss.export_as_string("tsv", 0))
      
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
      
      ws2 = session.worksheet_by_url(ws.cells_feed_url)
      assert_equal(ws.cells_feed_url, ws2.cells_feed_url)
      assert_equal("hoge", ws2.title)
      
      ss_copy_title = "google-spreadsheet-ruby test copy " + Time.now.strftime("%Y-%m-%d-%H-%M-%S")
      ss_copy = ss.duplicate(ss_copy_title)
      assert_not_nil(session.spreadsheets("title" => ss_copy_title).
        find(){ |s| s.title == ss_copy_title })
      assert_equal("3", ss_copy.worksheets[0][1, 1])
      
      # Access via GoogleSpreadsheet::Worksheet#list.
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

      ss.delete()
      assert_nil(session.spreadsheets("title" => ss_title).
        find(){ |s| s.title == ss_title })
      ss_copy.delete(true)
      assert_nil(session.spreadsheets("title" => ss_copy_title).
        find(){ |s| s.title == ss_copy_title })
      ss.delete(true)
    end
end
