# Author: Mateusz Czerwinski <mtczerwinski@gmail.com>
# The license of this source is "New BSD Licence"

require 'json'

module GoogleDrive
  class Config #:nodoc:
    attr_accessor :client_id, :client_secret, :scope, :refresh_token,
                  :config_path

    FIELDS = %w(client_id client_secret scope refresh_token).freeze

    def initialize(config_path)
      @config_path = config_path
    end

    def load_config_file
      json = ::File.read(config_path)
      parsed =  parse(json) || empty_hash
      parsed.each do |key, value|
        instance_variable_set("@#{key}", value) if FIELDS.include? key
      end
    end

    def save
      ::File.open(config_path, 'w') { |file| file.write(to_json) }
    end

    def valid?
      client_id? && client_secret?
    end

    private

    def parse(json)
      JSON.parse(json)
    rescue JSON::ParserError
      nil
    end

    def client_id?
      !client_id.nil? && !client_id.empty?
    end

    def client_secret?
      !client_secret.nil? && !client_secret.empty?
    end

    def empty_hash
      {
        client_id: '',
        client_secret: '',
        refresh_token: ''
      }
    end

    def to_json
      hash = {}
      FIELDS.each { |field| hash[field] = send(field) || '' }
      JSON.pretty_generate(hash)
    end
  end
end
