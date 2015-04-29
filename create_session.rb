require 'google_drive'

def create_session
   client = Google::APIClient.new(application_name: 'GoogleDriveIrb', application_version: '1')
   service_account_email_address = ''  #get from config vars 
   private_key = %Q||  #get from config vars 
   key = OpenSSL::PKey::RSA.new(private_key, 'notasecret')

   client.authorization = Signet::OAuth2::Client.new(
     :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
     :audience             => 'https://accounts.google.com/o/oauth2/token',
     :scope                => 'https://docs.google.com/feeds/ https://docs.googleusercontent.com/ https://spreadsheets.google.com/feeds/',
     :issuer               => service_account_email_address,
     :signing_key          => key
   ).tap { |auth| auth.fetch_access_token! }

   token = client.authorization.fetch_access_token!['access_token']

   GoogleDrive.login_with_oauth(token)
end

__END__

session = create_session
ss = session.spreadsheet_by_key('1gke4Gq2srjwRVsykldq8eV60Rp3oeC501uXkjbNkuog')
ws = ss.worksheet_by_title('Homeserve')
list = ws.list
qry = list.new_query
col = list.columnize('Order Reference')
qry.spreadsheet_query = col.concat('=576318-9')
list.fetch(qry)

row = list.first
row.store('Payment Date', '2014-10-31')
row.save

newrow = row.clean_dup
newrow.update('Order Reference' => '576324-17', 'Payment Date' => '2014-11-05')
newrow.insert

qry.max_results = 5
qry.start_index = 14
qry.reverse = true
