# Author: Guy Boertje <https://github.com/guyboertje>
# Author: David R. Albrecht <https://github.com/eldavido>
# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

# acl.rb, derived from https://github.com/guyboertje/gdata-spreadsheet-ruby/blob/master/lib/document.rb
# more frankensteining of the original library

module GoogleSpreadsheet
    
    class Acl
        
        include(Util)
        
        #:nodoc:
        PARAM_NAMES = [:acl_list, :scope_type, :scope, :role, :title, :edit_url, :etag]
        
        def initialize(params)
          @params = {:role => "reader"}
          for name, value in params
            if !PARAM_NAMES.include?(name)
              raise(ArgumentError, "Invalid key: %p" % name)
            end
            @params[name] = value
          end
        end
        
        #:nodoc:
        attr_accessor(:params)
        
        PARAM_NAMES.each() do |name|
          define_method(name) do
            return @params[name]
          end
        end
        
        def role=(role)
          @params[:acl_list].update_role(self, role)
        end
        
        def inspect
          return "\#<%p scope_type=%p, scope=%p, role=%p>" %
              [self.class, @params[:scope_type], @params[:scope], @params[:role]]
        end
        
    end
    
end

