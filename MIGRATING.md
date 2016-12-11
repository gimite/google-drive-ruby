# Migrating from version 1.x.x to 2.x.x

google-drive-ruby 1.x.x depends on google-api-client 0.8.x and Google Drive API V2.

google-drive-ruby 2.x.x depends on google-api-client 0.9.x and Google Drive API V3.

Each of them involves incompatible API changes. The users of google-drive-ruby may be affected by these changes.

Here are some changes likely affecting google-drive-ruby users:

If you pass an instance of Google::APIClient to GoogleDrive.login_with_oauth, it will no longer work, because Google::APIClient.new was removed. See [Authorization document](https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md) for new ways to pass credentials.

The field "title" in search queries was renamed to "name". e.g.,

```ruby
session.files(q: "title = 'hoge'")
```

must be rewritten to:

```ruby
session.files(q: "name = 'hoge'")
```

# Migrating from version 0.x.x to 2.x.x

Ver. 0.x.x no longer works, because the API used was deprecated and shut down. You need to migrate to ver. 1.x.x or later.

Ver. 1.x.x / 2.x.x are not 100% backward compatible with 0.x.x. Some methods have been removed. Especially, GoogleDrive.login has been removed, and you must use OAuth. See [Authorization document](https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md) for details.
