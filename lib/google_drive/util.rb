# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require 'cgi'

module GoogleDrive
  # @api private
  module Util
    EXT_TO_CONTENT_TYPE = {
      '.csv' => 'text/csv',
      '.tsv' => 'text/tab-separated-values',
      '.tab' => 'text/tab-separated-values',
      '.doc' => 'application/msword',
      '.docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.ods' => 'application/x-vnd.oasis.opendocument.spreadsheet',
      '.odt' => 'application/vnd.oasis.opendocument.text',
      '.rtf' => 'application/rtf',
      '.sxw' => 'application/vnd.sun.xml.writer',
      '.txt' => 'text/plain',
      '.xls' => 'application/vnd.ms-excel',
      '.xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.pdf' => 'application/pdf',
      '.png' => 'image/png',
      '.ppt' => 'application/vnd.ms-powerpoint',
      '.pps' => 'application/vnd.ms-powerpoint',
      '.pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.htm' => 'text/html',
      '.html' => 'text/html',
      '.zip' => 'application/zip',
      '.swf' => 'application/x-shockwave-flash'
    }.freeze

    IMPORTABLE_CONTENT_TYPE_MAP = {
      'application/x-vnd.oasis.opendocument.presentation' => 'application/vnd.google-apps.presentation',
      'text/tab-separated-values' => 'application/vnd.google-apps.spreadsheet',
      'image/jpeg' => 'application/vnd.google-apps.document',
      'image/bmp' => 'application/vnd.google-apps.document',
      'image/gif' => 'application/vnd.google-apps.document',
      'application/vnd.ms-excel.sheet.macroenabled.12' => 'application/vnd.google-apps.spreadsheet',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.template' => 'application/vnd.google-apps.document',
      'application/vnd.ms-powerpoint.presentation.macroenabled.12' => 'application/vnd.google-apps.presentation',
      'application/vnd.ms-word.template.macroenabled.12' => 'application/vnd.google-apps.document',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'application/vnd.google-apps.document',
      'image/pjpeg' => 'application/vnd.google-apps.document',
      'application/vnd.google-apps.script+text/plain' => 'application/vnd.google-apps.script',
      'application/vnd.ms-excel' => 'application/vnd.google-apps.spreadsheet',
      'application/vnd.sun.xml.writer' => 'application/vnd.google-apps.document',
      'application/vnd.ms-word.document.macroenabled.12' => 'application/vnd.google-apps.document',
      'application/vnd.ms-powerpoint.slideshow.macroenabled.12' => 'application/vnd.google-apps.presentation',
      'text/rtf' => 'application/vnd.google-apps.document',
      'text/plain' => 'application/vnd.google-apps.document',
      'application/vnd.oasis.opendocument.spreadsheet' => 'application/vnd.google-apps.spreadsheet',
      'application/x-vnd.oasis.opendocument.spreadsheet' => 'application/vnd.google-apps.spreadsheet',
      'image/png' => 'application/vnd.google-apps.document',
      'application/x-vnd.oasis.opendocument.text' => 'application/vnd.google-apps.document',
      'application/msword' => 'application/vnd.google-apps.document',
      'application/pdf' => 'application/vnd.google-apps.document',
      'application/json' => 'application/vnd.google-apps.script',
      'application/x-msmetafile' => 'application/vnd.google-apps.drawing',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.template' => 'application/vnd.google-apps.spreadsheet',
      'application/vnd.ms-powerpoint' => 'application/vnd.google-apps.presentation',
      'application/vnd.ms-excel.template.macroenabled.12' => 'application/vnd.google-apps.spreadsheet',
      'image/x-bmp' => 'application/vnd.google-apps.document',
      'application/rtf' => 'application/vnd.google-apps.document',
      'application/vnd.openxmlformats-officedocument.presentationml.template' => 'application/vnd.google-apps.presentation',
      'image/x-png' => 'application/vnd.google-apps.document',
      'text/html' => 'application/vnd.google-apps.document',
      'application/vnd.oasis.opendocument.text' => 'application/vnd.google-apps.document',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation' => 'application/vnd.google-apps.presentation',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 'application/vnd.google-apps.spreadsheet',
      'application/vnd.google-apps.script+json' => 'application/vnd.google-apps.script',
      'application/vnd.openxmlformats-officedocument.presentationml.slideshow' => 'application/vnd.google-apps.presentation',
      'application/vnd.ms-powerpoint.template.macroenabled.12' => 'application/vnd.google-apps.presentation',
      'text/csv' => 'application/vnd.google-apps.spreadsheet',
      'application/vnd.oasis.opendocument.presentation' => 'application/vnd.google-apps.presentation',
      'image/jpg' => 'application/vnd.google-apps.document',
      'text/richtext' => 'application/vnd.google-apps.document'
    }.freeze

    module_function

    def encode_query(params)
      params
        .map { |k, v| CGI.escape(k.to_s) + '=' + CGI.escape(v.to_s) }
        .join('&')
    end

    def concat_url(url, piece)
      (url_base, url_query) = url.split(/\?/, 2)
      (piece_base, piece_query) = piece.split(/\?/, 2)
      result_query =
        [url_query, piece_query].select { |s| s && !s.empty? }.join('&')
      (url_base || '') +
        (piece_base || '') +
        (result_query.empty? ? '' : "?#{result_query}")
    end

    def h(str)
      # Should also escape "\n" to keep it in cell contents.
      CGI.escapeHTML(str.to_s).gsub(/\n/, '&#x0a;')
    end

    def construct_query(arg)
      case arg

      when String
        arg

      when Array
        if arg[0].scan(/\?/).size != arg.size - 1
          raise(
            ArgumentError,
            format(
              "The number of placeholders doesn't match the number of " \
              'arguments: %p',
              arg
            )
          )
        end
        i = 1
        arg[0].gsub(/\?/) do
          v = arg[i]
          i += 1
          case v
          when String
            format("'%s'", v.gsub(/['\\]/) { '\\' + $& })
          when Time
            format("'%s'", v.iso8601)
          when TrueClass
            'true'
          when FalseClass
            'false'
          else
            raise(
              ArgumentError,
              format('Expected String, Time, true or false, but got %p', v)
            )
          end
        end

      else
        raise(
          ArgumentError, format('Expected String or Array, but got %p', arg)
        )

      end
    end

    def construct_and_query(args)
      args
        .select { |a| a }.map { |a| format('(%s)', construct_query(a)) }
        .join(' and ')
    end

    def convert_params(params)
      str_params = {}
      params.each do |k, v|
        str_params[k.to_s] = v
      end

      old_terms = []
      new_params = {}
      str_params.each do |k, v|
        case k
        when 'q'
          new_params[:q] = construct_query(v)

        # Parameters in the old API.
        when 'title'
          if str_params['title-exact'].to_s == 'true'
            old_terms.push(['name = ?', v])
          else
            old_terms.push(['name contains ?', v])
          end
        when 'title-exact'
        # Skips it. It is handled above.
        when 'opened-min'
          old_terms.push(['lastViewedByMeDate >= ?', v])
        when 'opened-max'
          old_terms.push(['lastViewedByMeDate <= ?', v])
        when 'edited-min'
          old_terms.push(['modifiedDate >= ?', v])
        when 'edited-max'
          old_terms.push(['modifiedDate <= ?', v])
        when 'owner'
          old_terms.push(['? in owners', v])
        when 'writer'
          old_terms.push(['? in writers', v])
        when 'reader'
          old_terms.push(['? in readers', v])
        when 'showfolders'
          if v.to_s == 'false'
            old_terms.push("mimeType != 'application/vnd.google-apps.folder'")
          end
        when 'showdeleted'
          old_terms.push('trashed = false') if v.to_s == 'false'
        when 'ocr', 'targetLanguage', 'sourceLanguage'
          raise(
            ArgumentError, format("'%s' parameter is no longer supported.", k)
          )
        else
          # e.g., 'pageToken' -> :page_token
          new_key = k
                    .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                    .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                    .downcase
                    .intern
          new_params[new_key] = v
        end
      end

      unless old_terms.empty?
        if new_params.key?(:q)
          raise(
            ArgumentError,
            "Cannot specify both 'q' parameter and old query parameters."
          )
        else
          new_params[:q] = construct_and_query(old_terms)
        end
      end

      new_params
    end

    def get_singleton_class(obj)
      class << obj
        return self
      end
    end

    def delegate_api_methods(obj, api_obj, exceptions = [])
      sc = get_singleton_class(obj)
      names = api_obj.public_methods(false) - exceptions
      names.each do |name|
        next if name.to_s =~ /=$/
        sc.__send__(:define_method, name) do
          api_obj.__send__(name)
        end
      end
    end
  end
end
