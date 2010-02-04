Gem::Specification.new do |s|
  s.name = %q{google-spreadsheet-ruby}
  s.version = "0.1.1"
  s.authors = ["Hiroshi Ichikawa"]
  s.date = %q{2010-01-31}
  s.description = %q{This is a library to read/write Google Spreadsheet.}
  s.email = ["gimite+github@gmail.com"]
  s.extra_rdoc_files = ["README.rdoc"]
  s.files = ["README.rdoc", "lib/google_spreadsheet.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/gimite/google-spreadsheet-ruby/tree/master}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{This is a library to read/write Google Spreadsheet.}
  s.specification_version = 2 if s.respond_to? :specification_version=

  s.add_dependency("hpricot", [">= 0.3"])
  s.add_dependency("oauth", [">= 0.3.6"])
end
