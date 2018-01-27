# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require 'forwardable'

require 'google_drive/util'
require 'google_drive/error'

module GoogleDrive
  # Hash-like object returned by GoogleDrive::List#[].
  class ListRow
    include(Enumerable)
    extend(Forwardable)

    def_delegators(:to_hash,
                   :keys, :values, :each_key, :each_value, :each, :each_pair,
                   :hash, :assoc, :fetch, :flatten, :key, :invert, :size,
                   :length, :rassoc, :merge, :reject, :select, :sort, :to_a,
                   :values_at)

    # @api private
    def initialize(list, index)
      @list = list
      @index = index
    end

    def [](key)
      @list.get(@index, key)
    end

    def numeric_value(key)
      @list.numeric_value(@index, key)
    end

    def input_value(key)
      @list.input_value(@index, key)
    end

    def []=(key, value)
      @list.set(@index, key, value)
    end

    def has_key?(key)
      @list.keys.include?(key)
    end

    alias include? has_key?
    alias key? has_key?
    alias member? has_key?

    def update(hash)
      hash.each do |k, v|
        self[k] = v
      end
    end

    alias merge! update

    def replace(hash)
      clear
      update(hash)
    end

    def clear
      @list.keys.each do |key|
        self[key] = ''
      end
    end

    def to_hash
      result = {}
      @list.keys.each do |key|
        result[key] = self[key]
      end
      result
    end

    def ==(other)
      self.class == other.class && to_hash == other.to_hash
    end

    alias === ==
    alias eql? ==

    def inspect
      format("\#<%p %p>", self.class, to_hash)
    end
  end
end
