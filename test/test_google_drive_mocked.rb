# The license of this source is "New BSD Licence"
$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
require 'yaml'

require 'rubygems'
require 'bundler/setup'
require 'test/unit'
require 'rspec/mocks'

require 'google_drive'
require 'google/api_client'

class TestGoogleDriveMocked < Test::Unit::TestCase
  include ::RSpec::Mocks::ExampleMethods
  CONFIG_FILEPATH = File.expand_path('../../tmp/config.json', __FILE__)

  def setup
    FileUtils.rm_f(CONFIG_FILEPATH)
    ::RSpec::Mocks.setup
  end

  def teardown
    ::RSpec::Mocks.verify if passed?
  ensure
    ::RSpec::Mocks.teardown
  end

  def swallow_stderr
    require 'stringio'
    old_stderr = STDERR
    $stderr = StringIO.new
    yield
  ensure
    $stderr = old_stderr
  end

  def mocked_auth
    double('Auth').tap do |auth|
      allow(auth).to receive(:client_id=)
      allow(auth).to receive(:client_secret=)
      allow(auth).to receive(:scope=)
      allow(auth).to receive(:redirect_uri=)
      allow(auth).to receive(:fetch_access_token!)
    end
  end

  def expect_mocked_google_client_to_return_auth_object
    mocked_auth.tap do |auth|
      client = instance_double(Google::APIClient)
      expect(Google::APIClient).to receive(:new).and_return(client)
      expect(client).to receive(:authorization).and_return(auth)
      expect(GoogleDrive).to receive(:login_with_oauth).with(client)
    end
  end

  def test_works_with_nothing
    auth = expect_mocked_google_client_to_return_auth_object
    refresh_token = 'some_token'
    config = GoogleDrive::Config.new(CONFIG_FILEPATH)
    expect(GoogleDrive::Config).to receive(:new).with(ENV['HOME'] + '/.ruby_google_drive.token').and_return(config)
    allow(config).to receive(:refresh_token).and_return(refresh_token)
    expect(auth).to receive(:refresh_token=).with(refresh_token)
    GoogleDrive.saved_session
  end

  def test_works_with_explicit_path_without_refresh_token
    src_path = File.expand_path('../fixtures/config_minimal.json', __FILE__)
    FileUtils.cp(src_path, CONFIG_FILEPATH)

    auth = expect_mocked_google_client_to_return_auth_object
    refresh_token = 'my-retrieved-refresh'
    expect_auth_to_provide_refresh_token(auth, refresh_token)

    swallow_stderr do
      GoogleDrive.saved_session(CONFIG_FILEPATH)
    end
    assert_file_contains(CONFIG_FILEPATH,
                         client_id: 'some client id',
                         client_secret: 'some client secret',
                         refresh_token: refresh_token
                        )
  end

  def expect_auth_to_provide_refresh_token(auth, retrieved_refresh_token)
    expect(auth).to receive(:refresh_token).and_return(retrieved_refresh_token)
    expect(auth).to receive(:authorization_uri).and_return('something')
    allow(STDIN).to receive(:gets) { 'some-code' }
    expect(auth).to receive(:code=).and_return('some-code')
  end

  def test_works_with_explicit_path_with_refresh_token
    src_path = File.expand_path('../fixtures/config_with_refresh.json', __FILE__)
    FileUtils.cp(src_path, CONFIG_FILEPATH)

    auth = expect_mocked_google_client_to_return_auth_object
    configs_refresh_token = 'already-refresh'
    expect(auth).to receive(:refresh_token=).and_return(configs_refresh_token)

    GoogleDrive.saved_session(CONFIG_FILEPATH)
    assert_file_contains(CONFIG_FILEPATH,
                         client_id: 'some id2',
                         client_secret: 'some secret2',
                         refresh_token: configs_refresh_token
                        )
  end

  def test_works_with_explicit_config_with_refresh
    config = double('some config object', client_id: 'some id', client_secret: 'client secret')
    allow(config).to receive(:scope)
    allow(config).to receive(:scope=)
    allow(config).to receive(:refresh_token).and_return('a refresh token')
    allow(config).to receive(:save)

    auth = expect_mocked_google_client_to_return_auth_object
    configs_refresh_token = 'already-refresh'
    expect(auth).to receive(:refresh_token=).and_return(configs_refresh_token)

    GoogleDrive.saved_session(config)
  end

  def test_works_with_explicit_config_without_refresh
    config = double('some config object', client_id: 'some id', client_secret: 'client secret')
    allow(config).to receive(:scope)
    allow(config).to receive(:scope=)
    allow(config).to receive(:refresh_token).and_return(nil)

    auth = expect_mocked_google_client_to_return_auth_object
    refresh_token = 'my-retrieved-refresh'
    expect_auth_to_provide_refresh_token(auth, refresh_token)

    expect(config).to receive(:refresh_token=).with(refresh_token)
    expect(config).to receive(:save)
    swallow_stderr do
      GoogleDrive.saved_session(config)
    end
  end

  def assert_file_contains(path, values)
    json = JSON.parse(::File.read(path))
    values.each_pair do |k, v|
      assert_equal(json[k.to_s], v, k.to_s)
    end
  end
end
