Gem::Specification.new do |s|
  s.name = %q{google-spreadsheet-ruby}
  s.version = "0.0.3"
  s.authors = ["Hiroshi Ichikawa"]
  s.date = %q{2009-07-13}
  s.description = %q{This is a library to read/write Google Spreadsheet.}
  s.email = ["gimite+github@gmail.com"]
  s.extra_rdoc_files = ["README.txt"]
  s.files = ["README.txt", "lib/google_spreadsheet.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/gimite/google-spreadsheet-ruby/tree/master}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{This is a library to read/write Google Spreadsheet.}

  if s.respond_to? :specification_version
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0')
      s.add_development_dependency(%q<hpricot>, [">= 0.3"])
    else
      s.add_dependency(%q<hpricot>, [">= 0.3"])
    end
  else
    s.add_dependency(%q<hpricot>, [">= 0.3"])
  end
end
