# acl.rb, derived from https://github.com/guyboertje/gdata-spreadsheet-ruby/blob/master/lib/document.rb
# more frankensteining of the original library

module GoogleSpreadsheet
  class Acl
    include Util
    attr_reader :title,:edit_url,:role,:scope,:scope_type,:new

    def initialize(session,doc,entry)
      @session = session
      @document = doc
      extract_vals(entry)
    end
    
    def update_role(role="reader")
      xml = <<-EOS
        <entry xmlns="http://www.w3.org/2005/Atom" xmlns:gAcl='http://schemas.google.com/acl/2007' xmlns:gd='http://schemas.google.com/g/2005'
            gd:etag="#{@etag}">
          <category scheme='http://schemas.google.com/g/2005#kind' term='http://schemas.google.com/acl/2007#accessRule'/>
          <gAcl:role value="#{role}"/>
          <gAcl:scope type="#{@scope_type}" value="#{@scope}"/>
        </entry>
      EOS
      
      doc = @session.request(:put, @edit_url)
      extract_vals(doc.root)
    end
    
    def delete
      @session.request(:delete, @edit_url)
      @document.acl_removed
    end
    
    def new?
      @new != 0  
    end
    
    def batch_id
      "s-#{@scope}_t-#{@scope_type}_r-#{@role}"
    end
    
    def inspect
      "<GdataSpreadsheet::Acl: @etag=#{@etag}, @title=#{@title}, @edit_url=#{@edit_url}, @role=#{@role}, @scope_type=#{@scope_type}, @scope=#{@scope}, @new =#{@new}>"
    end
    
    private
    def extract_vals(entry)
      if entry.kind_of?(Hash)
        @role = entry[:role]
        @scope_type = entry[:type]
        @scope = entry[:scope]
        @new = 1
      elsif entry.kind_of?(Nokogiri::XML::Node)
        @etag = entry["etag"]
        @title = text_from_xpath(entry,"./xmlns:title")
        @edit_url = href_from_rel(entry,"edit")
        @role = value_from_xpath(entry,"./gAcl:role","value")
        @scope_type = value_from_xpath(entry,"./gAcl:scope","type")
        @scope = value_from_xpath(entry,"./gAcl:scope","value")
        @new = 0
      else
        raise(GdataSpreadsheet::Error, "Incompatible object passed to GdataSpreadsheet::Acl.new")
      end
    end
  end
end

