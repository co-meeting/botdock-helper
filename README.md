# ForceBots

HubotにSalesforce認証機能を追加するForceBotsは以下のように使用する。

```coffeescript
ForceBots = require 'forcebots'

module.exports = (robot) ->
  force = new ForceBots(robot)

  robot.respond /LOGIN$/i, (res) ->
    force.sendAuthorizationUrl(res)

  robot.respond /PING$/i, (res) ->
    force.getJsforceConnection(res)
    .then (conn) ->
      conn.query "SELECT Id, Name FROM Account"
    .then (result) ->
      console.log("total : " + result.totalSize)
      console.log("fetched : " + result.records.length)

      res.send "total: " + result.totalSize
    .catch (err, result) ->
      console.error err
```
