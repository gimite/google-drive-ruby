This is a library to read/write Google Spreadsheet.


= How to install

TBD


= How to use

Example:
  
  require "rubygems"
  require "google_spreadsheet"
  
  # Logs in.
  session = GoogleSpreadsheet.login("username@gmail.com", "mypassword")
  
  # First worksheet of http://spreadsheets.google.com/ccc?key=pz7XtlQC-PYx-jrVMJErTcg&hl=en
  ws = session.spreadsheet_by_key("pz7XtlQC-PYx-jrVMJErTcg").worksheets[0]
  
  # Gets content of A2 cell.
  p ws[2, 1] #==> "hoge"
  
  # Changes content of cells. Changes are not sent to the server until you call ws.save().
  ws[2, 1] = "foo"
  ws[2, 2] = "bar"
  ws.save()
  
  # Reloads the worksheet to get changes by other clients.
  ws.reload()
