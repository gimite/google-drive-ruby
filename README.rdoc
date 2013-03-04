This is a Ruby 1.8/1.9/2.0 library to read/write files/spreadsheets in Google Drive/Docs.

NOTE: This is NOT a library to create Google Drive App.


= How to install

  $ sudo gem install google_drive


= How to use

Example to read/write files in Google Drive:

  require "rubygems"
  require "google_drive"
  
  # Logs in.
  # You can also use OAuth. See document of
  # GoogleDrive.login_with_oauth for details.
  session = GoogleDrive.login("username@gmail.com", "mypassword")
  
  # Gets list of remote files.
  for file in session.files
    p file.title
  end
  
  # Uploads a local file.
  session.upload_from_file("/path/to/hello.txt", "hello.txt", :convert => false)
  
  # Downloads to a local file.
  file = session.file_by_title("hello.txt")
  file.download_to_file("/path/to/hello.txt")
  
  # Updates content of the remote file.
  file.update_from_file("/path/to/hello.txt")

Example to read/write spreadsheets:
  
  require "rubygems"
  require "google_drive"
  
  # Logs in.
  # You can also use OAuth. See document of
  # GoogleDrive.login_with_oauth for details.
  session = GoogleDrive.login("username@gmail.com", "mypassword")
  
  # First worksheet of
  # https://docs.google.com/spreadsheet/ccc?key=pz7XtlQC-PYx-jrVMJErTcg
  ws = session.spreadsheet_by_key("pz7XtlQC-PYx-jrVMJErTcg").worksheets[0]
  
  # Gets content of A2 cell.
  p ws[2, 1]  #==> "hoge"
  
  # Changes content of cells.
  # Changes are not sent to the server until you call ws.save().
  ws[2, 1] = "foo"
  ws[2, 2] = "bar"
  ws.save()
  
  # Dumps all cells.
  for row in 1..ws.num_rows
    for col in 1..ws.num_cols
      p ws[row, col]
    end
  end
  
  # Yet another way to do so.
  p ws.rows  #==> [["fuga", ""], ["foo", "bar]]
  
  # Reloads the worksheet to get changes by other clients.
  ws.reload()

API document: http://gimite.net/doc/google-drive-ruby/


= Source code

http://github.com/gimite/google-drive-ruby

The license of this source is "New BSD Licence"


= Supported environments

Ruby 1.8.x, 1.9.x and 2.0.x. Checked with Ruby 1.8.7, 1.9.3 and 2.0.0.


= Author

Hiroshi Ichikawa - http://gimite.net/en/index.php?Contact
