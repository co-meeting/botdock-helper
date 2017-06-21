jsforce = require('jsforce')
redis = require('redis')

class BotDockHelper
  REQUIRED_ENVS = [
    'REDIS_URL'
    'SALESFORCE_CLIENT_ID'
    'SALESFORCE_CLIENT_SECRET'
    'SALESFORCE_REDIRECT_URI'
    'SALESFORCE_ORG_ID'
  ]

  # BotDockHelperのコンストラクタ
  # 
  # @param [hubot.Robot] Hubotのrobotオブジェクト
  # 
  constructor: (@robot) ->
    @log = @_createLogger @robot

    unsetEnvs = (env for env in REQUIRED_ENVS when !process.env[env])
    if unsetEnvs.length > 0
      throw "#{unsetEnvs.join(', ')} must be specified."

    # リトライ間隔は最大30分
    @client0 = @_createRedisClient()
    @client = @_createRedisClient()

    # direct組織IDとRedis DB indexのマップ保存用
    @redisDBMap = {}

    @oauth2 = new jsforce.OAuth2 {
      loginUrl : process.env.SALESFORCE_LOGIN_URL
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

    sessionId = @_generateSessionId()

    unless @client0.connected
      @log.warning "#{userId} REDIS_DOWN"
      res.send "現在メンテナンス中です。大変ご不便をおかけいたしますが、今しばらくお待ちください。"
      return

    @_findDB(res)
      .then (dbindex) =>
        @log.info "sessionId: #{sessionId}, userId: #{userId}, db: #{dbindex}"
        @client0.multi()
          .hmset sessionId,
            {
              userId: userId
              db: dbindex
              orgId: @_getDomainId(res)
              sfOrgId: process.env.SALESFORCE_ORG_ID
            }
          .expire(sessionId, 360)
          .exec (err, result) =>
            throw err if err

            authUrl = @oauth2.getAuthorizationUrl {state: sessionId}
            res.send "このBotを利用するには、Salesforceにログインする必要があります。\n
以下のURLからSalesforceにログインしてください。\n
#{authUrl}"
      .catch (err) =>
        @log.error err
        res.send "ログインURLの生成に失敗しました。"

  # jsforceのConnectionオブジェクトを取得します。
  #
  # @param [hubot.Response] res HubotのResponseオブジェクト
  # @option options [String] userId res.message.user.id以外のユーザIDにOAuthトークンを関連付けたい場合に指定する
  # @option options [String] skipGroupTalkHelp グループトークで認証していないユーザへの案内を非表示にする
  # @return [Promise] jsforceのConnectionオブジェクトをラップしたPromiseオブジェクト
  getJsforceConnection: (res, options = {}) ->
    new Promise (resolve, reject) =>
      userId = options.userId || res.message?.user?.id
      unless userId
        res.send "不正な操作です。"
        reject {code:"INVALID_PARAM", message:"cannot get User ID"}
        return

      unless @client.connected
        @log.warning "#{userId} REDIS_DOWN"
        res.send "現在メンテナンス中です。大変ご不便をおかけいたしますが、今しばらくお待ちください。"
        reject {code:"REDIS_DOWN", message:"Redis is down."}
        return

      @_findDB(res)
      .then (dbindex) =>
        @log.debug "userId=#{userId}, dbindex=#{dbindex}"

        @client.multi()
          .select(dbindex)
          .hgetall(userId)
          .exec (err, result) =>
            oauthInfo = result[1]
            if err
              reject err
              return

            unless oauthInfo
              @sendAuthorizationUrl res, options
              reject {code:"NO_AUTH", message:"認証していません"}
              return

            conn = new jsforce.Connection
              oauth2: @oauth2
              instanceUrl: oauthInfo.instanceUrl
              accessToken: oauthInfo.accessToken
              refreshToken: oauthInfo.refreshToken

            conn.on "refresh", (accessToken, res) =>
              @log.info "get new accessToken: #{accessToken}"
              @client.multi()
                .select(dbindex)
                .hset(userId, "accessToken", accessToken)
                .exec (err, result) =>
                  @log.info "save to redis accessToken: #{accessToken}"
            
            resolve conn

  # join時に接続がなければ認証URLをユーザに送ります。
  # join時のみ使用してください。
  #
  # @param [hubot.Response] res HubotのResponseオブジェクト
  # @return [Promise] jsforceのConnectionオブジェクトをラップしたPromiseオブジェクト
  checkAuthenticationOnJoin: (res) ->
    @getJsforceConnection(res, { userId:@_getUserIdOnJoin(res), skipGroupTalkHelp:true })

  # 認証情報を削除します。
  # 
  # @param [hubot.Response] res HubotのResponseオブジェクト
  logout: (res) ->
    if res.message.roomType != 1
      res.send "グループトークではログアウトできません。"
      return

    userId = res.message?.user?.id
    unless userId
      res.send "不正な操作です。"
      return

    unless @client.connected
      @log.warning "#{userId} REDIS_DOWN"
      res.send "現在メンテナンス中です。大変ご不便をおかけいたしますが、今しばらくお待ちください。"
      return

    @_findDB(res)
    .then (dbindex) =>
      @client.multi()
      .select(dbindex)
      .del(userId)
      .exec (err, result) =>
        throw err if err
        res.send "ログアウトしました。"
        @getJsforceConnection(res)
    .catch (err) =>
      @log.error err
      res.send "ログアウトに失敗しました。"

  # Bot毎にデータを保存します。
  #
  # @param [hubot.Response] res HubotのResponseオブジェクト
  # @param [String] key 
  # @param [Object] value 保存するデータ
  # @return [Promise]
  setData: (res, key, value) ->
    robotId = @_getRobotId()
    objectStr = JSON.stringify value
    new Promise (resolve, reject) =>
      @_findDB(res)
      .then (dbindex) =>
        @client.multi()
        .select(dbindex)
        .hset(robotId, key, objectStr)
        .exec (err, result) =>
          if err
            reject err
          else
            resolve result[1]
      .catch (err) =>
        reject err

  # Bot毎に保存したデータを取得します。
  #
  # @param [hubot.Response] res HubotのResponseオブジェクト
  # @param [String] key 
  # @return [Promise] 取得したデータをラップしたPromiseオブジェクト
  getData: (res, key) ->
    robotId = @_getRobotId()
    new Promise (resolve, reject) =>
      @_findDB(res)
      .then (dbindex) =>
        @client.multi()
        .select(dbindex)
        .hget(robotId, key)
        .exec (err, result) =>
          if err
            reject err
          else
            resolve JSON.parse(result[1])
      .catch (err) =>
        reject err

  # 現在の組織用のRedisDB Indexを取得
  # @private
  _findDB: (res, index = 1) ->
    orgId = @_getDomainId(res)
    if index >= 1000
      return Promise.reject "DBは1000までしか使用できません。"
    if @redisDBMap[orgId]
      return Promise.resolve @redisDBMap[orgId]
    new Promise (resolve, reject) =>
      unless @client.connected
        @log.warning "REDIS_DOWN"
        res.send "現在メンテナンス中です。大変ご不便をおかけいたしますが、今しばらくお待ちください。"
        reject {code:"REDIS_DOWN", message:"Redis is down."}
        return

      @client.multi()
        .select(index)
        .get('ORGANIZATION_ID')
        .exec (err, result) =>
          return reject(err) if err

          if result[1] == orgId
            @redisDBMap[orgId] = index
            resolve index
            return

          unless result[1]
            @client.multi()
              .select(index)
              .set('ORGANIZATION_ID', orgId)
              .exec (err, resSet) =>
                @redisDBMap[orgId] = index
                resolve index
            return

          @_findDB(res, index + 1)
            .then (resFind) =>
              resolve resFind
            .catch (err) =>
              reject err
  
  # RedisClientを作成
  # @private
  _createRedisClient: ->
    client = redis.createClient(process.env.REDIS_URL, {retry_max_delay:30*60*1000})
    client.on 'error', (err) =>
      @log.error err.message
  
  # セッションIDを生成
  # @private
  _generateSessionId: ->
    (Math.random().toString(36).substr(3, 11) for i in [1..3]).join('')

  # ペアトークにjoin時に相手のユーザIDを取得する
  # @private
  _getUserIdOnJoin: (res) ->
    if !res.message?.roomUsers || res.message.roomUsers.length != 2
      return
    unless res.message?.user?.id
      return
    for user in res.message.roomUsers
      if user.id != res.message.user.id
        return user.id
    return

  # Direct BotのユーザIDを取得
  # @private
  _getRobotId: ->
    robotId = @robot.adapter.bot?.data?.me?.id
    if !robotId || !robotId.high || !robotId.low
      throw new Error "Cannot get robot Id."
    "_#{robotId.high}_#{robotId.low}"

  # Directの組織IDを収得
  # @private
  _getDomainId: (res) ->
    res.message.rooms[res.message.room].domainId

  # 改行を削除
  # @private
  _createLogFunc: (level) ->
    (msg) =>
      @robot.logger[level] "#{msg || ''}".replace(/\r?\n/g, '\\n')

  # ロガーを作成
  # @private
  _createLogger: (robot) ->
    if process.env.LOGGER && process.env.LOGGER == 'console'
      {
        debug: console.log
        info: console.info
        warning: console.warn
        error: console.error
      }
    else
      logger = {}
      for level in ['debug', 'info', 'warning', 'error']
        logger[level] = @_createLogFunc(level)
      logger


module.exports = BotDockHelper
