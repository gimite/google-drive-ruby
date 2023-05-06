Gem::Specification.new do |s|
  s.name = 'google_drive'
  s.version = '3.0.7'
  s.authors = ['Hiroshi Ichikawa']
  s.email = ['gimite+github@gmail.com']
  s.summary = 'A library to read/write files/spreadsheets in Google Drive/Docs.'
  s.description = 'A library to read/write files/spreadsheets in Google Drive/Docs.'
  s.homepage = 'https://github.com/gimite/google-drive-ruby'
  s.rubygems_version = '1.2.0'
  s.license = 'BSD-3-Clause'
  s.required_ruby_version = '>= 2.0.0'

  s.files = ['README.md'] + Dir['lib/**/*']
  s.require_paths = ['lib']

  s.add_dependency('nokogiri', ['>= 1.5.3'])
  s.add_dependency('google-apis-drive_v3', '>= 0.5.0')
  s.add_dependency('google-apis-sheets_v4', '>= 0.4.0')
  s.add_dependency('googleauth', ['>= 0.5.0'])
  s.add_development_dependency('test-unit', ['>= 3.0.0', '< 4.0.0'])
  s.add_development_dependency('rake', ['>= 0.8.0'])
  s.add_development_dependency('rspec-mocks', ['>= 3.4.0', '< 4.0.0'])
end
