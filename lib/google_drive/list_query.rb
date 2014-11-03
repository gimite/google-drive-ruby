module GoogleDrive
  class ListQuery < Query
    SPREADSHEET_QUERY = 'sq'.freeze
    ORDERBY = 'orderby'.freeze
    ORDERBY_COLUMN = 'column'.freeze
    ORDERBY_POSITION = 'position'.freeze
    REVERSE = 'reverse'.freeze

    def spreadsheet_query=(value)
      @store[SPREADSHEET_QUERY] = value.to_s
    end

    def spreadsheet_query
      @store[SPREADSHEET_QUERY]
    end

    def reverse=(value)
      @store[REVERSE] = value.to_s
    end

    def reverse
      @store[REVERSE]
    end
  end
end
