# 追加メソット
GoogleDrive::Spreadsheet#add_worksheet_from_template(name)
シートを追加するときにtemplateという名前があればそこからコピーして新たに作る。


This is a Ruby library to read/write files/spreadsheets in Google Drive/Docs.

NOTE: This is NOT a library to create Google Drive App.


## Migration from ver. 0.x.x / 1.x.x to to ver. 2.x.x

There are some incompatible API changes. See
[MIGRATING.md](https://github.com/gimite/google-drive-ruby/blob/master/MIGRATING.md).


## How to install

Add this line to your application's Gemfile:

```ruby
gem 'google_drive'
```

And then execute:

```
$ bundle
```

Or install it yourself as:

```
$ gem install google_drive
```

If you need system wide installation, execute below:

```
$ sudo gem install google_drive
```

## How to use

### Authorization

Follow one of the options in [Authorization](https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md) to construct a session object. The example code below assumes "On behalf of you" option.

### Example to read/write files in Google Drive

```ruby
require "google_drive"

# Creates a session. This will prompt the credential via command line for the
# first time and save it to config.json file for later usages.
session = GoogleDrive::Session.from_config("config.json")

# Gets list of remote files.
session.files.each do |file|
  p file.title
end

# Uploads a local file.
session.upload_from_file("/path/to/hello.txt", "hello.txt", convert: false)

# Downloads to a local file.
file = session.file_by_title("hello.txt")
file.download_to_file("/path/to/hello.txt")

# Updates content of the remote file.
file.update_from_file("/path/to/hello.txt")
```

### Example to read/write spreadsheets

```ruby
require "google_drive"

# Creates a session. This will prompt the credential via command line for the
# first time and save it to config.json file for later usages.
session = GoogleDrive::Session.from_config("config.json")

# First worksheet of
# https://docs.google.com/spreadsheet/ccc?key=pz7XtlQC-PYx-jrVMJErTcg
# Or https://docs.google.com/a/someone.com/spreadsheets/d/pz7XtlQC-PYx-jrVMJErTcg/edit?usp=drive_web
ws = session.spreadsheet_by_key("pz7XtlQC-PYx-jrVMJErTcg").worksheets[0]

# Gets content of A2 cell.
p ws[2, 1]  #==> "hoge"

# Changes content of cells.
# Changes are not sent to the server until you call ws.save().
ws[2, 1] = "foo"
ws[2, 2] = "bar"
ws.save

# Dumps all cells.
(1..ws.num_rows).each do |row|
  (1..ws.num_cols).each do |col|
    p ws[row, col]
  end
end

# Yet another way to do so.
p ws.rows  #==> [["fuga", ""], ["foo", "bar]]

# Reloads the worksheet to get changes by other clients.
ws.reload
```

## Learn more

* [API documentation](http://www.rubydoc.info/gems/google_drive/2.1.1)
* [Authorization](https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md)
* [Github](http://github.com/gimite/google-drive-ruby)

## License

New BSD Licence.

## Supported environments

Ruby 2.0.0 or later. Checked with Ruby 2.3.0.

## Author

[Hiroshi Ichikawa](http://gimite.net/en/index.php?Contact)


