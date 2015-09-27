jsforce = require('jsforce')
redis = require('redis')

#
# HubotにSalesforce認証機能を追加します。
# 起動時に指定したDOMAIN環境変数ごとにトークン情報保存先のRedisのDBを分けます。
#
# 以下の環境変数が必須です。
# - DOMAIN : 利用団体を区別するためのキー。例）example.com
# - REDIS_URL : 情報保存先のRedisのURL 例）redis://127.0.0.1:6379
# - SALESFORCE_CLIENT_ID : Salesforceの接続アプリケーションのクライアントID
# - SALESFORCE_CLIENT_SECRET : Salesforceの接続アプリケーションのクライアントシークレット
# - SALESFORCE_REDIRECT_URI : Salesforceの接続アプリケーションのコールバックURL。bot-auth-serverのURLを指定する。
# 
# @example 使い方
#   ForceBots = require '../lib/forcebots'
#
#   module.exports = (robot) ->
#     force = new ForceBots(robot)
#
#     robot.respond /LOGIN$/i, (res) ->
#       force.sendAuthorizationUrl(res)
#
#     robot.respond /PING$/i, (res) ->
#       force.getJsforceConnection(res)
#       .then (conn) ->
#         conn.query "SELECT Id, Name FROM Account"
#       .then (result) ->
#         console.log("total : " + result.totalSize)
#         console.log("fetched : " + result.records.length)
#
#         res.send "total: " + result.totalSize
#       .catch (err, result) ->
#         console.error err
class ForceBots
  _generateSessionId = ->
    Math.random().toString(36).substring(3)

  _findDB = (client, index = 1) ->
    domain = process.env.DOMAIN
    new Promise (resolve, reject) ->
      client.multi()
        .select(index)
        .get('domain')
        .exec (err, result) ->
          if result[1] == domain
            resolve index
            return

          unless result[1]
            client.set 'domain', domain, (err, resSet) ->
              resolve index
            return

          if index >= 1000
            reject "DBは1000までしか使用できません。"
            return

          _findDB(client, index + 1)
            .then (resFind) ->
              resolve resFind
            .catch (err) ->
              reject err

  # ForceBotsのコンストラクタ
  # 
  # @param [hubot.Robot] Hubotのrobotオブジェクト
  # 
  constructor: (@robot) ->
    _this = @
    logger = @robot.logger
    unless process.env.DOMAIN &&
        process.env.REDIS_URL && 
        process.env.SALESFORCE_CLIENT_ID && 
        process.env.SALESFORCE_CLIENT_SECRET && 
        process.env.SALESFORCE_REDIRECT_URI
      logger.error "DOMAIN, REDIS_PORT, REDIS_HOST, SALESFORCE_CLIENT_ID, SALESFORCE_CLIENT_SECRET, SALESFORCE_REDIRECT_URI must be specified."
      process.exit 0

    # リトライ間隔は最大30分
    @client0 = redis.createClient(process.env.REDIS_URL, {retry_max_delay:30*60*1000})
    @client0.on 'error', (err) ->
      logger.error err.message
    @client = redis.createClient(process.env.REDIS_URL, {retry_max_delay:30*60*1000})
    @client.on 'error', (err) ->
      logger.error err.message

    _findDB(@client)
      .then (dbindex) ->
        logger.info "DB #{dbindex} is selected."
        _this.dbindex = dbindex
      .catch (err) ->
        console.error err

    @oauth2 = new jsforce.OAuth2 {
      # you can change loginUrl to connect to sandbox or prerelease env.
      # loginUrl : 'https://test.salesforce.com',
      clientId : process.env.SALESFORCE_CLIENT_ID
      clientSecret : process.env.SALESFORCE_CLIENT_SECRET
      redirectUri : process.env.SALESFORCE_REDIRECT_URI
    }

  # SalesforceのAuthroization URLをユーザに送信します。
  # 
  # @param [hubot.Response] res HubotのResponseオブジェクト
  sendAuthorizationUrl: (res) ->
    _this = @
    oauth2 = @oauth2
    client0 = @client0
    logger = @robot.logger
    userId = res.message?.user?.id
    unless userId
      res.send "cannot get User ID"
      logger.error err
      return

    sessionId = _generateSessionId()
    logger.info "sessionId: #{sessionId}, userId: #{userId}, db: #{@dbindex}"

    unless client0.connected
      res.send "現在メンテナンス中です。大変ご不便をおかけいたしますが、今しばらくお待ちください。"
      return

    client0.multi()
      .hmset sessionId,
        {
          userId: userId
          db: @dbindex
        }
      .expire(sessionId, 360)
      .exec (err, result) ->
        if err
          logger.error err
          return

        authUrl = oauth2.getAuthorizationUrl {state: sessionId}
        res.send "このBotを利用するには、以下のURLからSalesforceにログインしてください。\n#{authUrl}"

  # jsforceのConnectionオブジェクトを取得します。
  #
  # @param [hubot.Response] res HubotのResponseオブジェクト
  # @return [Promise] jsforceのConnectionオブジェクトをラップしたPromiseオブジェクト
  getJsforceConnection: (res) ->
    _this = @
    oauth2 = @oauth2
    client = @client
    logger = @robot.logger
    new Promise (resolve, reject) ->
      userId = res.message?.user?.id
      unless userId
        res.send "cannot get User ID"
        reject "cannot get User ID"
        return

      unless client.connected
        res.send "現在メンテナンス中です。大変ご不便をおかけいたしますが、今しばらくお待ちください。"
        reject "Redis is down."
        return

      client.hgetall userId, (err, oauthInfo) ->
        if err
          reject err
          return

        unless oauthInfo
          _this.sendAuthorizationUrl res
          reject "認証していません"
          return

        conn = new jsforce.Connection
          oauth2: oauth2
          instanceUrl: oauthInfo.instanceUrl
          accessToken: oauthInfo.accessToken
          refreshToken: oauthInfo.refreshToken

        conn.on "refresh", (accessToken, res) ->
          logger.info "get new accessToken: #{accessToken}"
          client.hset userId, "accessToken", accessToken, ->
            logger.info "save to redis accessToken: #{accessToken}"
        
        resolve conn

module.exports = ForceBots
