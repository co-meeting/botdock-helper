jsforce = require('jsforce')
redis = require('redis')

class BotDockHelper
  _generateSessionId = ->
    Math.random().toString(36).substring(3)

  _findDB = (client, index = 1) ->
    orgId = process.env.SALESFORCE_ORG_ID
    new Promise (resolve, reject) ->
      client.multi()
        .select(index)
        .get('SALESFORCE_ORG_ID')
        .exec (err, result) ->
          if result[1] == orgId
            resolve index
            return

          unless result[1]
            client.set 'SALESFORCE_ORG_ID', orgId, (err, resSet) ->
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

  # ペアトークにjoin時に相手のユーザIDを取得する
  _getUserIdOnJoin = (res) ->
    if !res.message?.roomUsers || res.message.roomUsers.length != 2
      return
    unless res.message?.user?.id
      return
    for user in res.message.roomUsers
      if user.id != res.message.user.id
        return user.id
    return

  # BotDockHelperのコンストラクタ
  # 
  # @param [hubot.Robot] Hubotのrobotオブジェクト
  # 
  constructor: (@robot) ->
    _this = @
    logger = @robot.logger
    unless process.env.SALESFORCE_ORG_ID &&
        process.env.REDIS_URL && 
        process.env.SALESFORCE_CLIENT_ID && 
        process.env.SALESFORCE_CLIENT_SECRET && 
        process.env.SALESFORCE_REDIRECT_URI
      logger.error "SALESFORCE_ORG_ID, REDIS_PORT, REDIS_HOST, SALESFORCE_CLIENT_ID, SALESFORCE_CLIENT_SECRET, SALESFORCE_REDIRECT_URI must be specified."
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
  # @option options [String] userId res.message.user.id以外のユーザIDにOAuthトークンを関連付けたい場合に指定する
  # @option options [String] skipGroupTalkHelp グループトークで認証していないユーザへの案内を非表示にする
  sendAuthorizationUrl: (res, options = {}) ->
    _this = @
    oauth2 = @oauth2
    client0 = @client0
    logger = @robot.logger

    userId = options.userId || res.message?.user?.id
    unless userId
      res.send "cannot get User ID"
      return

    if res.message.roomType != 1
      unless options.skipGroupTalkHelp
        res.send "#{res.message.user.name}さん\n
まだSalesforceへの認証ができていないため、ご利用いただけません。\n
まずペアトークで私に話しかけて認証をしてからご利用ください。"
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
          sfOrgId: process.env.SALESFORCE_ORG_ID
        }
      .expire(sessionId, 360)
      .exec (err, result) ->
        if err
          logger.error err
          return

        authUrl = oauth2.getAuthorizationUrl {state: sessionId}
        res.send "このBotを利用するには、Salesforceにログインする必要があります。\n
以下のURLからSalesforceにログインしてください。\n
#{authUrl}"

  # jsforceのConnectionオブジェクトを取得します。
  #
  # @param [hubot.Response] res HubotのResponseオブジェクト
  # @option options [String] userId res.message.user.id以外のユーザIDにOAuthトークンを関連付けたい場合に指定する
  # @option options [String] skipGroupTalkHelp グループトークで認証していないユーザへの案内を非表示にする
  # @return [Promise] jsforceのConnectionオブジェクトをラップしたPromiseオブジェクト
  getJsforceConnection: (res, options = {}) ->
    _this = @
    oauth2 = @oauth2
    client = @client
    logger = @robot.logger
    new Promise (resolve, reject) ->
      userId = options.userId || res.message?.user?.id
      unless userId
        res.send "cannot get User ID"
        reject {code:"INVALID_PARAM", message:"cannot get User ID"}
        return

      unless client.connected
        res.send "現在メンテナンス中です。大変ご不便をおかけいたしますが、今しばらくお待ちください。"
        reject {code:"REDIS_DOWN", message:"Redis is down."}
        return

      client.hgetall userId, (err, oauthInfo) ->
        if err
          reject err
          return

        unless oauthInfo
          _this.sendAuthorizationUrl res, options
          reject {code:"NO_AUTH", message:"認証していません"}
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

  # join時に接続がなければ認証URLをユーザに送ります。
  # join時のみ使用してください。
  #
  # @param [hubot.Response] res HubotのResponseオブジェクト
  # @return [Promise] jsforceのConnectionオブジェクトをラップしたPromiseオブジェクト
  checkAuthenticationOnJoin: (res) ->
    this.getJsforceConnection(res, { userId:_getUserIdOnJoin(res), skipGroupTalkHelp:true })

module.exports = BotDockHelper
