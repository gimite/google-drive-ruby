# Author: Guy Boertje <https://github.com/guyboertje>
# The license of this source is "New BSD Licence"
require 'google_drive/util'

module GoogleDrive
  # Row behaves like a hash
  # converts a list feed entry (Nokogiri element) to a hash
  # unpacks the gsx namespaced elements [name, text]
  class Row < SimpleDelegator
    include Util
    # class factory methods

    def self.build(entry)
      row = new
      row.accept_entry entry
    end

    ENTRY_NSX = %Q|<entry xmlns='http://www.w3.org/2005/Atom' xmlns:gsx='http://schemas.google.com/spreadsheets/2006/extended'>|.freeze

    attr_reader :entry, :list
    # instance methods

    def dup
      row = self.class.new
      row.accept_row(self).with_list(@list)
    end

    def clean_dup
      row = self.class.new
      row.accept_keys(self).with_list(@list)
    end

    def initialize
      super Hash.new
    end

    def with_list(list)
      @list = list
      self
    end

    def store(key, value)
      k = key.to_s.gsub(/\p{^Alnum}/, '').downcase.to_sym
      __getobj__.store(k, value)
    end

    def update(hash)
      hash.each do |k,v|
        store(k,v)
      end
    end

    def insert
      @list.upload_insert(self)
    end

    def save
      @list.upload_update(self)
    end

    def edit_url
      raise ArgumentError.new("can't edit: entry not supplied") if @entry.nil?
      @entry.at_css("link[rel='edit']")['href']
    end

    def as_insert_xml
      xml = ENTRY_NSX.dup
      each do |k, v|
        tag = 'gsx:'.concat(k.to_s)
        xml.concat("<#{tag}>#{h(v)}</#{tag}>")
      end
      xml.concat('</entry>')
    end

    def as_update_xml
      raise ArgumentError.new("can't update: entry not supplied") if @entry.nil?
      each do |k, v|
        node = @entry.at_xpath("gsx:#{k}")
        node.content = h(v)
      end
      @entry.to_xml.sub!('<entry>', ENTRY_NSX)
    end

    def accept_entry(entry)
      @entry = entry
      entry.xpath('gsx:*').each do |field|
        store field.name.to_sym, field.text
      end
      self
    end

    def accept_row(row)
      row.each {|k,v| store(k, v)}
      self
    end

    def accept_keys(row)
      row.keys.each {|k| store(k, nil)}
      self
    end
  end
end
