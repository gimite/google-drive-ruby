# The license of this source is "New BSD Licence"
$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
require 'yaml'

require 'rubygems'
require 'bundler/setup'
require 'test/unit'
require 'rspec/mocks'

require 'google_drive'

class TestWorksheet < Test::Unit::TestCase
  include ::RSpec::Mocks::ExampleMethods

  def setup
    ::RSpec::Mocks.setup
  end

  def teardown
    ::RSpec::Mocks.verify if passed?
  ensure
    ::RSpec::Mocks.teardown
  end

  def worksheet_feed_entry
    @worksheet_feed_entry ||= Nokogiri.XML(<<-XML
    <some-element-or-other>
      <title>Some title</title>
      <updated>20160213</updated>
      <link rel='http://schemas.google.com/spreadsheets/2006#cellsfeed' href="CELLS_FEED_URL"/>
    </some-element-or-other>
    XML
                                          )
  end

  def cells_feed
    @cells_feed ||= Nokogiri.XML(File.open(File.expand_path('./fixtures/worksheet_cells_feed.xml')))
  end

  def mocked_session
    @session ||= instance_double(GoogleDrive::Session).tap do |session|
      allow(session).to receive(:request).with(:get, 'CELLS_FEED_URL').and_return(cells_feed)
    end
  end

  def mocked_spreadsheet
    instance_double(GoogleDrive::Spreadsheet)
  end

  def test_that_cell_assignment_works_with_ascii_with_rowcol
    worksheet = GoogleDrive::Worksheet.new(mocked_session, mocked_spreadsheet, worksheet_feed_entry)
    worksheet[1, 1] = 'some text'
    assert_equal('some text', worksheet.input_value(1, 1))
  end

  def test_that_cell_assignment_works_with_utf8_with_rowcol
    worksheet = GoogleDrive::Worksheet.new(mocked_session, mocked_spreadsheet, worksheet_feed_entry)
    worksheet[2, 3] = '面白い'
    assert_equal('面白い', worksheet.input_value(2, 3))
  end

  def test_that_cell_assignment_works_with_utf8_with_cellref
    worksheet = GoogleDrive::Worksheet.new(mocked_session, mocked_spreadsheet, worksheet_feed_entry)
    worksheet['C4'] = '面白い'
    assert_equal('面白い', worksheet.input_value(4, 3))
  end

  def test_that_cell_assignment_raises_an_error_with_bad_characters
    worksheet = GoogleDrive::Worksheet.new(mocked_session, mocked_spreadsheet, worksheet_feed_entry)
    assert_raise ArgumentError do
      worksheet[1, 1] = "some text\u001A面白い"
    end
  end
end
