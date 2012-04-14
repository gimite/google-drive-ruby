Gem::Specification.new do |s|
  
  s.name = "google-spreadsheet-ruby"
  s.version = "0.2.1"
  s.authors = ["Hiroshi Ichikawa"]
  s.email = ["gimite+github@gmail.com"]
  s.summary = "This is a library to read/write Google Spreadsheet."
  s.description = "This is a library to read/write Google Spreadsheet."
  s.homepage = "https://github.com/gimite/google-spreadsheet-ruby"
  s.rubygems_version = "1.2.0"
  
  s.files = [
      "README.rdoc",
      "lib/google_spreadsheet.rb",
      "lib/google_spreadsheet/acl.rb",
      "lib/google_spreadsheet/acl_entry.rb",
      "lib/google_spreadsheet/authentication_error.rb",
      "lib/google_spreadsheet/client_login_fetcher.rb",
      "lib/google_spreadsheet/collection.rb",
      "lib/google_spreadsheet/error.rb",
      "lib/google_spreadsheet/list.rb",
      "lib/google_spreadsheet/list_row.rb",
      "lib/google_spreadsheet/oauth1_fetcher.rb",
      "lib/google_spreadsheet/oauth2_fetcher.rb",
      "lib/google_spreadsheet/record.rb",
      "lib/google_spreadsheet/session.rb",
      "lib/google_spreadsheet/spreadsheet.rb",
      "lib/google_spreadsheet/table.rb",
      "lib/google_spreadsheet/util.rb",
      "lib/google_spreadsheet/worksheet.rb",
  ]
  s.require_paths = ["lib"]
  s.has_rdoc = true
  s.extra_rdoc_files = [
      "README.rdoc",
      "doc_src/google_spreadsheet/acl.rb",
      "doc_src/google_spreadsheet/acl_entry.rb",
  ]
  s.rdoc_options = ["--main", "README.rdoc"]

  s.add_dependency("nokogiri", [">= 1.4.4", "!= 1.5.1", "!= 1.5.2"])
  s.add_dependency("oauth", [">= 0.3.6"])
  s.add_dependency("oauth2", [">= 0.5.0"])
  s.add_development_dependency("rake", [">= 0.8.0"])
  
end
