require 'rake'
require 'rake/testtask'

task :default => [:test]

desc "Run unit tests"
Rake::TestTask.new("test") { |t|
  t.pattern = 'test/*.rb'
  t.verbose = true
  t.warning = true
}
