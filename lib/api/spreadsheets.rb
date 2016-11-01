class SpreadsheetsApi
  def initialize(access_token, client_id)
    @access_token = access_token
    @client_id = client_id
  end

  # https://developers.google.com/sheets/reference/rest/v4/spreadsheets.sheets/copyTo
  def copy_to(spreadsheet_id, template_sheet_id, destination_spreadsheet_id)
    url = "https://sheets.googleapis.com/v4/spreadsheets/#{spreadsheet_id}/sheets/#{template_sheet_id}:copyTo?key=#{@client_id}"
    uri = URI.parse(url)
    body = {
      'destinationSpreadsheetId' => destination_spreadsheet_id
    }.to_json

    post(uri, body)
  end

  private
  def post(uri, body)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, header)
    req.body = body
    https.request(req) # return response
  end

  def header
    {
      'Authorization' => "Bearer #{@access_token}",
      'Content-Type' => 'application/json'
    }
  end
end
