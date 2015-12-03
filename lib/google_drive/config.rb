require 'json'

module GoogleDrive
  class Config #:nodoc:
    attr_accessor :client_id, :client_secret, :scope, :refresh_token, :config_path

    Fields = %w(client_id client_secret scope refresh_token).freeze

    def initialize(config_path)
      @config_path = ::File.expand_path(config_path)
    end

    def call
      load_config_file
    end

    def save
      ::File.open(config_path, 'w') { |file| file.write(prepare_json) }
    end

    private

    def prepare_json
      hash = {}
      Fields.each { |field| hash[field] = send(field) }
      hash.to_json
    end

    def load_config_file
      json = ::File.read(config_path)
      parsed = JSON.parse(json)
      parsed.each { |key, value| instance_variable_set("@#{key}", value) }
    end
  end
end
