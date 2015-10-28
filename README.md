# BotDock Helper

HubotにSalesforce認証機能を追加します。
起動時に指定したDOMAIN環境変数ごとにトークン情報保存先のRedisのDBを分けます。

以下の環境変数が必須です。

- DOMAIN : 利用団体を区別するためのキー。例）example.com
- REDIS_URL : 情報保存先のRedisのURL 例）redis://127.0.0.1:6379
- SALESFORCE_CLIENT_ID : Salesforceの接続アプリケーションのクライアントID
- SALESFORCE_CLIENT_SECRET : Salesforceの接続アプリケーションのクライアントシークレット
- SALESFORCE_REDIRECT_URI : Salesforceの接続アプリケーションのコールバックURL。bot-auth-serverのURLを指定する。

```coffeescript
BotDock = require 'botdock-helper'

module.exports = (robot) ->
  botdock = new BotDock(robot)

  robot.join (res) ->
    botdock.checkAuthenticationOnJoin(res)

  robot.respond /LOGIN$/i, (res) ->
    botdock.sendAuthorizationUrl(res)

  robot.respond /PING$/i, (res) ->
    botdock.getJsforceConnection(res)
    .then (conn) ->
      conn.query "SELECT Id, Name FROM Account"
    .then (result) ->
      console.log("total : " + result.totalSize)
      console.log("fetched : " + result.records.length)

      res.send "total: " + result.totalSize
    .catch (err, result) ->
      console.error err
```