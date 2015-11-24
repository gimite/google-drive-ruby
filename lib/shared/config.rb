require 'json'

require_relative 'errors/file_not_found'

module GoogleDrive
  class Config
    attr_accessor :client_id, :client_secret, :scope, :redirect_uris, :access_token

    def initialize
      return unless valid?
      load_config_file
    end

    def save
      ::File.open(file_path,'w') { |file| file.write(prepare_json) }
    end

    def access_token_exists?
      return access_token.empty? unless access_token.nil?
      false
    end

    private

    def prepare_json
      hash = Hash.new
      ['client_id', 'client_secret', 'scope', 'redirect_uris', 'access_token'].each do |field|
        hash[field] = send(field)
      end
      hash.to_json
    end

    def valid?
      raise GoogleDrive::FileNotFound.new unless ::File.exist?(file_path)
      true
    end

    def file_path
      ::File.expand_path('config.json')
    end

    def load_config_file
      json = ::File.open(file_path, 'r').read
      parsed = JSON.parse(json)
      parsed.each { |key, value| instance_variable_set("@#{key}", value) }
    end
  end
end
