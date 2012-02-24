# ugly frankensteining of gimite's library with something that forked off
# of it a few years ago...
# https://github.com/guyboertje/gdata-spreadsheet-ruby/blob/master/lib/document.rb

module GoogleSpreadsheet
  class SpreadsheetDocument
    include Util
    attr_reader :title,:spreadsheet,:ws_feed_url,:tbl_feed_url,:acl_feed_url,:self_url,:resource_id,:author
    def initialize(session,entry)
      @session = session
      @title = text_from_xpath(entry,"./xmlns:title")
      rid = text_from_xpath(entry,"./gd:resourceId")
      @resource_id = rid.split(':').last
      @self_url = href_from_rel(entry,'self')
      @ws_feed_url = href_from_rel(entry,'http://schemas.google.com/spreadsheets/2006#worksheetsfeed')
      @tbl_feed_url = href_from_rel(entry,'http://schemas.google.com/spreadsheets/2006#tablesfeed')
      @acl_feed_url = href_from_rel(entry,"http://schemas.google.com/acl/2007#accessControlList","./gd:feedLink")
      author_name = text_from_xpath(entry,"./xmlns:author/xmlns:name")
      author_email = text_from_xpath(entry,"./xmlns:author/xmlns:email")
      @author = {:name => author_name,:email => author_email}
      @acls = []
      @new_acls = []
      @acl_batch_url = ""
      @spreadsheet = Spreadsheet.new(session,self)
      @modified = false
    end
    
    def inspect
      "<GdataSpreadsheet::SpreadsheetDocument: @session=<GdataSpreadsheet::Session: Object>, @title=#{@title}, @resource_id=#{@resource_id}, @self_url=#{@self_url}, @ws_feed_url=#{@ws_feed_url}, @tbl_feed_url=#{@tbl_feed_url}, @acl_feed_url=#{@acl_feed_url}, @acl_batch_url=#{@acl_batch_url}, @modified=#{@modified}, @author=#{@author.inspect}, @acls=#{@acls.inspect}, @new_acls=#{@new_acls.inspect}, @spreadsheet=<dataSpreadsheet::Spreadsheet: Object>"
    end
    
    def add_acl(scope,scope_type,role="reader")
      load_acls if (@acl_batch_url.empty? || @acls.size == 0)
      h = {:scope=>scope,:type=>scope_type,:role=>role}
      @new_acls << Acl.new(@session,self,h)
    end
    
    def acl_removed
      load_acls
    end
    
    def save
      spreadsheet.save_worksheets
      save_acls
      load_acls
    end
    
    def acls
      load_acls if (@acls.empty? || @acl_batch_url.empty?)
      @acls
    end
    
    def save_acls
      #Use batch
      xml = ''
      @new_acls.each do |acl|
        if acl.new?
          xml << <<-EOS
            <entry>
              <batch:id>#{h(acl.batch_id)}</batch:id>
              <batch:operation type="insert"/>
              <gAcl:role value='#{acl.role}'/>
              <gAcl:scope type='#{acl.scope_type}' value='#{acl.scope}'/>
            </entry>
          EOS
        end
      end
      if xml.size > 0
        x = batch_xml_open_section(@acl_feed_url) + xml + batch_xml_close_section
        @session.batch_update(@acl_batch_url,x,:writely)
      end
      true
    end
    
    private
    def load_acls
      doc = @session.request(:get, acl_feed_url, :auth => :writely)
      @acl_batch_url = href_from_rel(doc.root,"http://schemas.google.com/g/2005#batch")
      @acls = doc.root.xpath("./xmlns:entry").map {|e| Acl.new(@session,self, e)}
    end
  end
end

