jsforce = require('jsforce')
redis = require('redis')

class BotDockHelper
  _generateSessionId = ->
    Math.random().toString(36).substring(3)

  _createRedisClient = ->
    logger = @log
    client = redis.createClient(process.env.REDIS_URL, {retry_max_delay:30*60*1000})
    client.on 'error', (err) ->
      logger.error err.message

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

  # Directの組織IDを収得
  _getDomainId = (res) ->
    res.message.rooms[res.message.room].domainId

  # 改行を削除
  _createLogFunc = (robot, level) ->
    (msg) ->
      robot.logger[level] "#{msg || ''}".replace(/\r?\n/g, '\\n')

  # ロガーを作成
  _createLogger = (robot) ->
    logger = {}
    for level in ['debug', 'info', 'warning', 'error']
      logger[level] = _createLogFunc(robot, level)
    logger

  # BotDockHelperのコンストラクタ
  # 
  # @param [hubot.Robot] Hubotのrobotオブジェクト
  # 
  constructor: (@robot) ->
    @log = _createLogger @robot
    logger = @log

    unless process.env.REDIS_URL && 
        process.env.SALESFORCE_CLIENT_ID && 
        process.env.SALESFORCE_CLIENT_SECRET && 
        process.env.SALESFORCE_REDIRECT_URI &&
        process.env.SALESFORCE_ORG_ID
      logger.error "REDIS_PORT, REDIS_HOST, SALESFORCE_CLIENT_ID, SALESFORCE_CLIENT_SECRET, SALESFORCE_REDIRECT_URI, SALESFORCE_ORG_ID must be specified."
      process.exit 0

    # リトライ間隔は最大30分
    @client0 = _createRedisClient()
    @client = _createRedisClient()

    # direct組織IDとRedis DB indexのマップ保存用
    @redisDBMap = {}

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
    logger = @log

    userId = options.userId || res.message?.user?.id
    unless userId
      res.send "不正な操作です。"
      return

    if res.message.roomType != 1
      unless options.skipGroupTalkHelp
        res.send "#{res.message.user.name}さん\n
まだSalesforceへの認証ができていないため、ご利用いただけません。\n
まずペアトークで私に話しかけて認証をしてからご利用ください。"
      return

    sessionId = _generateSessionId()

    unless client0.connected
      res.send "現在メンテナンス中です。大変ご不便をおかけいたしますが、今しばらくお待ちください。"
      return

    _this._findDB(res)
      .then (dbindex) ->
        logger.info "sessionId: #{sessionId}, userId: #{userId}, db: #{dbindex}"
        client0.multi()
          .hmset sessionId,
            {
              userId: userId
              db: dbindex
              orgId: _getDomainId(res)
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
      .catch (err) ->
        logger.error err

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
    logger = @log
    new Promise (resolve, reject) ->
      userId = options.userId || res.message?.user?.id
      unless userId
        res.send "不正な操作です。"
        reject {code:"INVALID_PARAM", message:"cannot get User ID"}
        return

      _this._findDB(res)
      .then (dbindex) ->
        logger.debug "userId=#{userId}, dbindex=#{dbindex}"
        unless client.connected
          res.send "現在メンテナンス中です。大変ご不便をおかけいたしますが、今しばらくお待ちください。"
          reject {code:"REDIS_DOWN", message:"Redis is down."}
          return

        client.multi()
          .select(dbindex)
          .hgetall(userId)
          .exec (err, result) ->
            oauthInfo = result[1]
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
              client.multi()
                .select(dbindex)
                .hset(userId, "accessToken", accessToken)
                .exec (err, result) ->
                  logger.info "save to redis accessToken: #{accessToken}"
            
            resolve conn
      .catch (err) ->
        reject err

  # join時に接続がなければ認証URLをユーザに送ります。
  # join時のみ使用してください。
  #
  # @param [hubot.Response] res HubotのResponseオブジェクト
  # @return [Promise] jsforceのConnectionオブジェクトをラップしたPromiseオブジェクト
  checkAuthenticationOnJoin: (res) ->
    this.getJsforceConnection(res, { userId:_getUserIdOnJoin(res), skipGroupTalkHelp:true })

  # 認証情報を削除します。
  # 
  # @param [hubot.Response] res HubotのResponseオブジェクト
  logout: (res) ->
    _this = @
    client = @client
    logger = @log

    if res.message.roomType != 1
      res.send "グループトークではログアウトできません。"
      return

    userId = res.message?.user?.id
    unless userId
      res.send "不正な操作です。"
      return

    _this._findDB(res)
    .then (dbindex) ->
      unless client.connected
        res.send "現在メンテナンス中です。大変ご不便をおかけいたしますが、今しばらくお待ちください。"
        return

      client.multi()
      .select(dbindex)
      .del(userId)
      .exec (err, result) ->
        if err
          res.send "ログアウトに失敗しました。"
          return
        res.send "ログアウトしました。"
        _this.getJsforceConnection(res)
    .catch (err) ->
      logger.error err
      res.send "ログアウトに失敗しました。"

  # 現在の組織用のRedisDB Indexを取得
  # @private
  _findDB: (res, index = 1) ->
    _this = @
    orgId = _getDomainId(res)
    if _this.redisDBMap[orgId]
      return new Promise (resolve, reject) ->
        resolve _this.redisDBMap[orgId]
    new Promise (resolve, reject) ->
      _this.client.multi()
        .select(index)
        .get('ORGANIZATION_ID')
        .exec (err, result) ->
          if result[1] == orgId
            _this.redisDBMap[orgId] = index
            resolve index
            return

          unless result[1]
            _this.client.multi()
              .select(index)
              .set('ORGANIZATION_ID', orgId)
              .exec (err, resSet) ->
                _this.redisDBMap[orgId] = index
                resolve index
            return

          if index >= 1000
            reject "DBは1000までしか使用できません。"
            return

          _this._findDB(res, index + 1)
            .then (resFind) ->
              resolve resFind
            .catch (err) ->
              reject err

module.exports = BotDockHelper
