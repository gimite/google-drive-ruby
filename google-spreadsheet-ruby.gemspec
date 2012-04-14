Gem::Specification.new do |s|
  
  s.name = "google-spreadsheet-ruby"
  s.version = "0.1.9"
  s.authors = ["Hiroshi Ichikawa"]
  s.email = ["gimite+github@gmail.com"]
  s.summary = "This is a library to read/write Google Spreadsheet."
  s.description = "This is a library to read/write Google Spreadsheet."
  s.homepage = "https://github.com/gimite/google-spreadsheet-ruby"
  s.rubygems_version = "1.2.0"
  
  s.files = ["README.rdoc", "lib/google_spreadsheet.rb"]
  s.require_paths = ["lib"]
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc"]
  s.rdoc_options = ["--main", "README.rdoc"]

  s.add_dependency("nokogiri", [">= 1.4.4", "!= 1.5.1", "!= 1.5.2"])
  s.add_dependency("oauth", [">= 0.3.6"])
  s.add_dependency("oauth2", [">= 0.5.0"])
  s.add_development_dependency("rake", [">= 0.8.0"])
  
end
