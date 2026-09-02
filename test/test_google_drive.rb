$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
require 'yaml'

require 'rubygems'
require 'bundler/setup'
require 'highline'
require 'test/unit'

require 'google_drive'

class TestGoogleDrive < Test::Unit::TestCase
  # Random string is added to avoid conflict with existing file titles.
  PREFIX = 'google-drive-ruby-test-4101301e303c-'.freeze

  @@session = nil

  def test_spreadsheet_online
    session = get_session

    ss_title = "#{PREFIX}spreadsheet"
    ss_copy_title = "#{PREFIX}spreadsheet-copy"

    # Removes test spreadsheets in the previous run in case the previous run
    # failed.
    for ss in session.files('title' => ss_title, 'title-exact' => 'true')
      delete_test_file(ss, true)
    end
    for ss in session.files('title' => ss_copy_title, 'title-exact' => 'true')
      delete_test_file(ss, true)
    end

    ss = session.create_spreadsheet(ss_title)
    assert { ss.title == ss_title }

    ws = ss.worksheets[0]
    assert { ws.spreadsheet.worksheets_feed_url == ss.worksheets_feed_url }
    ws.title = 'hoge'
    ws.max_rows = 20
    ws.max_cols = 10
    ws[1, 1] = '3'
    ws[1, 2] = '5'
    ws[1, 3] = '=A1+B1'
    ws[1, 4] = 13
    assert { ws.max_rows == 20 }
    assert { ws.max_cols == 10 }
    assert { ws.num_rows == 1 }
    assert { ws.num_cols == 4 }
    assert { ws[1, 1] == '3' }
    assert { ws[1, 2] == '5' }
    assert { ws[1, 4] == '13' }
    ws.save

    ws.reload
    assert { ws.max_rows == 20 }
    assert { ws.max_cols == 10 }
    assert { ws.num_rows == 1 }
    assert { ws.num_cols == 4 }
    assert { ws[1, 1] == '3' }
    assert { ws[1, 2] == '5' }
    assert { ws[1, 3] == '8' }
    assert { ws[1, 4] == '13' }
    assert { ws[1, 1].encoding == Encoding::UTF_8 }

    assert { ss.export_as_string('csv') == '3,5,8,13' }
    assert { ss.available_content_types.empty? }

    ss2 = session.spreadsheet_by_key(ss.key)
    assert { ss2.title == ss_title }
    assert { ss2.worksheets_feed_url == ss.worksheets_feed_url }
    assert { ss2.human_url == ss.human_url }
    assert { ss2.worksheets[0].title == 'hoge' }
    assert { ss2.worksheets[0][1, 1] == '3' }
    assert { ss2.worksheet_by_title('hoge').title == 'hoge' }
    assert { ss2.worksheet_by_title('foo').nil? }
    assert { ss2.title.encoding == Encoding::UTF_8 }
    assert { ss2.worksheets[0].title.encoding == Encoding::UTF_8 }

    ss3 = session.spreadsheet_by_url(
      "http://spreadsheets.google.com/ccc?key=#{ss.key}&hl=en"
    )
    assert { ss3.worksheets_feed_url == ss.worksheets_feed_url }
    ss4 = session.spreadsheet_by_url(ss.worksheets_feed_url)
    assert { ss4.worksheets_feed_url == ss.worksheets_feed_url }

    assert { session.spreadsheets.any? { |s| s.title == ss_title } }
    assert do
      session.spreadsheets('title' => ss_title, 'title-exact' => 'true')
             .any? { |s| s.title == ss_title }
    end

    ws2 = session.worksheet_by_url(ws.cells_feed_url)
    assert { ws2.cells_feed_url == ws.cells_feed_url }
    assert { ws2.title == 'hoge' }

    ss_copy = ss.duplicate(ss_copy_title)
    assert do
      session.spreadsheets('title' => ss_copy_title, 'title-exact' => 'true')
             .any? { |s| s.title == ss_copy_title }
    end
    assert { ss_copy.worksheets[0][1, 1] == '3' }

    ss5 = session.spreadsheet_by_title(ss_title)
    assert { ss5 }
    # This should be the one with title exact match, not ss_copy.
    assert { ss5.title == ss_title }

    # Access via GoogleDrive::Worksheet#list.
    ws.list.keys = %w[x y]
    ws.list.push('x' => '1', 'y' => '2')
    ws.list.push('x' => '3', 'y' => '4')
    assert { ws.list.keys == %w[x y] }
    assert { ws.list.size == 2 }
    assert { ws.list[0]['x'] == '1' }
    assert { ws.list[0]['y'] == '2' }
    assert { ws.list[1]['x'] == '3' }
    assert { ws.list[1]['y'] == '4' }
    assert { ws[1, 1] == 'x' }
    assert { ws[1, 2] == 'y' }
    assert { ws[2, 1] == '1' }
    assert { ws[2, 2] == '2' }
    assert { ws[3, 1] == '3' }
    assert { ws[3, 2] == '4' }
    ws.list[0]['x'] = '5'
    ws.list[1] = { 'x' => '6', 'y' => '7' }
    assert { ws.list[0]['x'] == '5' }
    assert { ws.list[0]['y'] == '2' }
    assert { ws.list[1]['x'] == '6' }
    assert { ws.list[1]['y'] == '7' }

    assert { ws.cell_name_to_row_col('A2') == [2, 1] }
    assert { ws.cell_name_to_row_col('Z2') == [2, 26] }
    assert { ws.cell_name_to_row_col('AA2') == [2, 27] }
    assert { ws.cell_name_to_row_col('AB2') == [2, 28] }

    # Makes sure we can access cells by name as well as by (row, col) pairs.
    assert { ws['A2'] == ws[2, 1] }
    assert { ws.input_value('A2') == ws.input_value(2, 1) }

    # Makes sure we can write to a cell by name.
    ws[2, 1] = '5'
    ws['A2'] = '555'
    assert { ws[2, 1] == '555' }

    # Test of update_cells().
    ws.update_cells(1, 1, [%w[1 2], %w[3 4]])
    assert { ws[1, 1] == '1' }
    assert { ws[2, 2] == '4' }
    ws.update_cells(2, 1, [%w[5 6], %w[7 8]])
    assert { ws[1, 1] == '1' }
    assert { ws[2, 2] == '6' }
    assert { ws[3, 1] == '7' }

    ws.insert_rows(2, 3)
    assert { ws[1, 1] == '1' }
    assert { ws[2, 1] == '' }
    assert { ws[3, 1] == '' }
    assert { ws[4, 1] == '' }
    assert { ws[5, 1] == '5' }
    assert { ws[6, 1] == '7' }

    ws.delete_rows(2, 3)
    assert { ws[1, 1] == '1' }
    assert { ws[2, 1] == '5' }
    assert { ws[3, 1] == '7' }

    ws.insert_rows(2, [%w[9 10], %w[11 12]])
    assert { ws[1, 1] == '1' }
    assert { ws[2, 1] == '9' }
    assert { ws[2, 2] == '10' }
    assert { ws[3, 1] == '11' }
    assert { ws[3, 2] == '12' }
    assert { ws[4, 1] == '5' }
    assert { ws[5, 1] == '7' }

    delete_test_file(ss)
    assert do
      session.spreadsheets(q: ['name = ? and trashed = false', ss_title]).empty?
    end
    delete_test_file(ss_copy, true)
    assert do
      session.spreadsheets('title' => ss_copy_title, 'title-exact' => 'true')
             .none? { |s| s.title == ss_copy_title }
    end
    delete_test_file(ss, true)
  end

  # Tests various manipulations with files and collections.
  def test_collection_and_file_online
    session = get_session

    # Gets root collection.
    root = session.root_collection
    assert { root.root? }

    test_collection_title = "#{PREFIX}collection"
    test_file_title = "#{PREFIX}file.txt"
    test_file2_title = "#{PREFIX}file2.txt"

    # Removes test files/collections in the previous run in case the previous
    # run failed.
    for title in [test_file_title, test_collection_title]
      for file in session.files(
        'title' => title, 'title-exact' => 'true', 'showfolders' => 'true'
      )
        delete_test_file(file, true)
      end
    end

    assert { root.subcollection_by_title(test_collection_title).nil? }

    # Creates collection.
    collection = root.create_subcollection(test_collection_title)
    assert { collection.is_a?(GoogleDrive::Collection) }
    assert { collection.title == test_collection_title }
    assert { !collection.root? }
    assert { !collection.resource_id.nil? }
    assert { !root.subcollection_by_title(test_collection_title).nil? }
    collection2 = session.collection_by_url(collection.document_feed_url)
    assert { collection2.files.empty? }
    collection3 = session.collection_by_url(
      format(
        'https://drive.google.com/#folders/%s',
        collection.resource_id.split(/:/)[1]
      )
    )
    assert { collection3.files.empty? }

    collection4 = session.collection_by_id(collection.id)
    assert { collection4.files.empty? }

    # Uploads a test file.
    test_file_path = File.join(File.dirname(__FILE__), 'test_file.txt')
    file = session.upload_from_file(
      test_file_path, test_file_title, convert: false
    )
    assert { file.is_a?(GoogleDrive::File) }
    assert { file.title == test_file_title }
    assert { file.available_content_types == ['text/plain'] }
    assert { file.download_to_string == File.read(test_file_path) }

    # Updates the content of the file.
    test_file2_path = File.join(File.dirname(__FILE__), 'test_file2.txt')
    file.update_from_file(test_file2_path)
    assert { file.download_to_string == File.read(test_file2_path) }

    # Uploads an empty file.
    file2 = session.upload_from_string(
      '', test_file2_title, content_type: 'text/plain', convert: false
    )
    assert { file2.is_a?(GoogleDrive::File) }
    assert { file2.title == test_file2_title }
    assert { file2.download_to_string == '' }

    # Checks if file exists in root.
    tfile = session.file_by_title(test_file_title)
    assert { !tfile.nil? }
    assert { tfile.title == test_file_title }
    tfile = root.file_by_title(test_file_title)
    assert { !tfile.nil? }
    assert { tfile.title == test_file_title }
    tfiles = root.files('title' => test_file_title, 'title-exact' => 'true')
    assert { tfiles.size == 1 }
    assert { tfiles[0].title == test_file_title }
    tfile = session.file_by_title([test_file_title])
    assert { !tfile.nil? }
    assert { tfile.title == test_file_title }

    # Moves file to collection.
    collection.add(file)
    root.remove(file)

    # Checks if file exists in collection.
    assert do
      root.files('title' => test_file_title, 'title-exact' => 'true').empty?
    end
    tfile = collection.file_by_title(test_file_title)
    assert { !tfile.nil? }
    assert { tfile.title == test_file_title }
    tfiles = collection.files(
      'title' => test_file_title, 'title-exact' => 'true'
    )
    assert { tfiles.size == 1 }
    assert { tfiles[0].title == test_file_title }
    tfile = session.file_by_title([test_collection_title, test_file_title])
    assert { !tfile.nil? }
    assert { tfile.title == test_file_title }

    # Deletes files.
    delete_test_file(file, true)
    delete_test_file(file2, true)
    # Ensure the file is removed from collection.
    assert do
      collection
        .files('title' => test_file_title, 'title-exact' => 'true')
        .empty?
    end
    # Ensure the file is removed from Google Drive.
    assert do
      session.files('title' => test_file_title, 'title-exact' => 'true').empty?
    end

    # Deletes collection.
    delete_test_file(collection, true)
    # Ensure the collection is removed from the root collection.
    assert do
      root
        .subcollections(
          'title' => test_collection_title,
          'title-exact' => 'true'
        ).empty?
    end
    # Ensure the collection is removed from Google Drive.
    assert do
      session.files(
        'title' => test_collection_title,
        'title-exact' => 'true',
        'showfolders' => 'true'
      ).empty?
    end
  end

  def test_acl_online
    session = get_session

    test_file_title = "#{PREFIX}acl-test-file"

    # Removes test files/collections in the previous run in case the previous
    # run failed.
    for file in session.files(
      'title' => test_file_title, 'title-exact' => 'true'
    )
      delete_test_file(file, true)
    end

    file = session.upload_from_string(
      'hoge', test_file_title, content_type: 'text/plain', convert: false
    )
    file.acl.push(scope_type: 'anyone', with_key: true, role: 'reader')
    acl = file.acl(reload: true).sort_by { |e| e.scope_type }
    assert { acl.size == 2 }

    assert { acl[0].scope_type == 'anyone' }
    assert { acl[0].with_key }
    assert { acl[0].role == 'reader' }
    assert { acl[0].value.nil? }

    assert { acl[1].scope_type == 'user' }
    assert { !acl[1].with_key }
    assert { acl[1].role == 'owner' }
    assert { !acl[1].value.nil? }

    acl[0].role = 'writer'
    assert { acl[0].role == 'writer' }
    acl = file.acl(reload: true).sort_by { |e| e.scope_type }
    assert { acl[0].role == 'writer' }

    delete_test_file(file, true)
  end

  def get_session
    unless @@session
      puts(
        "\nThis test will create files/spreadsheets/collections with your " \
        'account, read/write them and finally delete them (if everything ' \
        'succeeds).'
      )

      account_path = File.join(File.dirname(__FILE__), 'account.yaml')
      config_path = File.join(File.dirname(__FILE__), 'config.json')
      if File.exist?(account_path)
        raise(
          format(
            "%s is deprecated. Please delete it.\n" \
            'Instead, follow one of the instructions here to create either ' \
            'config.json or a service account key JSON file and put it at ' \
            "%s:\n" \
            'https://github.com/gimite/google-drive-ruby/blob/master/' \
            "README.md\#how-to-use",
            account_path, config_path
          )
        )
      end
      unless File.exist?(config_path)
        raise(
          format(
            "%s is missing.\n" \
            'Follow one of the instructions here to create either ' \
            'config.json or a service account key JSON file and put it at ' \
            "%s:\n" \
            'https://github.com/gimite/google-drive-ruby/blob/master/doc/' \
            'authorization.md',
            config_path, config_path
          )
        )
      end

      @@session = GoogleDrive::Session.from_config(
        config_path,
        client_options: {transparent_gzip_decompression: true},
        request_options: {retries: 3}
      )
    end
    @@session
  end

  # Wrapper of GoogleDrive::File#delete which makes sure not to delete non-test
  # files.
  def delete_test_file(file, permanent = false)
    esc_prefix = Regexp.escape(PREFIX)
    if file.title =~ Regexp.new("\\A#{esc_prefix}")
      file.delete(permanent)
    else
      raise(format('Trying to delete non-test file: %p', file))
    end
  end
end
