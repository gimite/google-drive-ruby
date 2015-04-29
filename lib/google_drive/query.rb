module GoogleDrive
  class Query

    FULL_TEXT = 'q'
    START_INDEX = 'start-index'.freeze
    START_TOKEN = 'start-token'.freeze
    MAX_RESULTS = 'max-results'.freeze

    def initialize(url)
      @store = Hash.new('')
      @url = url
    end

    def to_url
      return @url if @store.size.zero?
      "#{@url}?#{URI.encode_www_form(@store)}"
    end

    def feed_url=(url)
      @url = url
    end

    def full_text_query=(query)
      @store[FULL_TEXT] = query
    end

    def full_text_query
      @store[FULL_TEXT]
    end

    def start_index=(value)
      @store[START_INDEX] = value.to_i.abs
    end

    def start_index
      @store[START_INDEX]
    end

    def max_results=(value)
      @store[MAX_RESULTS] = value.to_i.abs
    end

    def max_results
      @store[MAX_RESULTS]
    end
  end
end

