# Authorization

There are multiple ways for authorization, based on whom your code access Google Drive on behalf of:

* [On behalf of you (command line authorization)](#command-line)
* [On behalf of the user who accesses your web app (web based authorization)](#web)
* [On behalf of no existing users (service account)](#service-account)

If you don't have access to your machine's command line, you need to choose between the last two options. In case you do need to authorize as yourself, use the second option and authorize as yourself on the web.

## <a name="command-line">On behalf of you (command line authorization)</a>

If you want your program to access Google Drive with your own account, or the account of the user who runs your program on the command line, follow these steps:

1. Go to the [API library page](https://console.developers.google.com/apis/library) in the Google Developer Console.
1. Create a new project, or select an existing project.<br>
![](https://raw.githubusercontent.com/gimite/google-drive-ruby/master/doc/images/create_project.png)
1. Enable "Google Drive API" and "Google Sheets API" for the project on the page.
1. Go to the [credentials page](https://console.developers.google.com/apis/credentials) in the Google Developer Console for the same project.
1. Click "Create credentials" -> "OAuth client ID".<br>
![](https://raw.githubusercontent.com/gimite/google-drive-ruby/master/doc/images/oauth_client_id.png)
1. Choose "Other" for "Application type".<br>
![](https://raw.githubusercontent.com/gimite/google-drive-ruby/master/doc/images/app_type_other.png)
1. Click "Create" and take note of the generated client ID and client secret.
1. Activate the Drive API for your project in the [Google API Console](https://console.developers.google.com/apis/library).
1. Create a file config.json which contains the client ID and client secret you got above, which looks like:
   ```
   {
     "client_id": "xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com",
     "client_secret": "xxxxxxxxxxxxxxxxxxxxxxxx"
   }

   ```
1. Then you can construct a session object by:
   ```ruby
   session = GoogleDrive::Session.from_config("config.json")

   ```
   This code will prompt the credential via command line for the first time and save it to config.json. For the second time and later, it uses the saved credential without prompt.

## <a name="web">On behalf of the user who accesses your web app (web based authorization)</a>

If you are developing a web app, and want your web app user to authorize with the user's account, follow these steps:

1. Go to the [API library page](https://console.developers.google.com/apis/library) in the Google Developer Console.
1. Create a new project, or select an existing project.<br>
![](https://raw.githubusercontent.com/gimite/google-drive-ruby/master/doc/images/create_project.png)
1. Enable "Google Drive API" and "Google Sheets API" for the project on the page.
1. Go to the [credentials page](https://console.developers.google.com/apis/credentials) in the Google Developer Console for the same project.
1. Click "Create credentials" -> "OAuth client ID".<br>
![](https://raw.githubusercontent.com/gimite/google-drive-ruby/master/doc/images/oauth_client_id.png)
1. Choose "Web application" for "Application type", and fill in the form.<br>
![](https://raw.githubusercontent.com/gimite/google-drive-ruby/master/doc/images/app_type_web.png)
1. Click "Create" and take note of the generated client ID and client secret.
1. Activate the Drive API for your project in the [Google API Console](https://console.developers.google.com/apis/library).
1. Write code like this to get auth_url:
   ```ruby
   require "googleauth"
    
   credentials = Google::Auth::UserRefreshCredentials.new(
     client_id: "YOUR CLIENT ID",
     client_secret: "YOUR CLIENT SECRET",
     scope: [
       "https://www.googleapis.com/auth/drive",
       "https://spreadsheets.google.com/feeds/",
     ],
     redirect_uri: "http://example.com/redirect")
   auth_url = credentials.authorization_uri
   ```
1. Redirect the user to auth_url. It will redirect back to the redirect_uri you passed, with an authorization code.
1. On access to the redirect_uri, construct a session object by this code:
   ```ruby
   credentials = ... same as above ...
   credentials.code = authorization_code
   credentials.fetch_access_token!
   session = GoogleDrive::Session.from_credentials(credentials)

   ```

The session above expires in 1 hour. If you want to restore a session afterwards, add `additional_parameters: { "access_type" => "offline" }` to the argument of Google::Auth::UserRefreshCredentials.new:

```ruby
credentials = Google::Auth::UserRefreshCredentials.new(
  ... same as above ...
  additional_parameters: { "access_type" => "offline" })
auth_url = credentials.authorization_uri
```

Then store credentials.refresh_token after credentials.fetch_access_token! above. Later, use this code to restore the session:

```ruby
credentials = ... same as above ...
credentials.refresh_token = refresh_token
credentials.fetch_access_token!
session = GoogleDrive::Session.from_credentials(credentials)
```

## <a name="service-account">On behalf of no existing users (service account)</a>

If you don't want your program to access Google Drive on behalf of any existing users, you can use a [service account](https://developers.google.com/identity/protocols/OAuth2ServiceAccount). It means that your program can only access:

* Files/documents created by the service account
* Files/documents explicitly shared with the service account
* Public files/documents

To use a service account, follow these steps:

1. Go to the [API library page](https://console.developers.google.com/apis/library) in the Google Developer Console.
1. Create a new project, or select an existing project.<br>
![](https://raw.githubusercontent.com/gimite/google-drive-ruby/master/doc/images/create_project.png)
1. Enable "Google Drive API" and "Google Sheets API" for the project on the page.
1. Go to the [credentials page](https://console.developers.google.com/apis/credentials) in the Google Developer Console for the same project.
1. Click "Create credentials" -> "Service account".<br>
![](https://raw.githubusercontent.com/gimite/google-drive-ruby/master/doc/images/service_account.png)
1. Click "Create" and download the keys as a JSON file.
1. Activate the Drive API for your project in the [Google API Console](https://console.developers.google.com/apis/library).
1. Construct a session object by code like this, passing the path to the downloaded JSON file:
   ```ruby
   session = GoogleDrive::Session.from_service_account_key(
       "my-service-account-xxxxxxxxxxxx.json")

   ```
   Optionally, you can pass the second argument which specifies the scope as an Array of String.

If you want to share your files/documents/folders with the service account, share them with the client_email address in the JSON file.
