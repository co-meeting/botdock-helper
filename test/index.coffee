chai    = require('chai')
sinon = require 'sinon'
sinonChai = require 'sinon-chai'
expect = chai.expect
chai.use sinonChai

BotDockHelper = require("../index")

jsforce = require('jsforce')

describe "botdock-helper", ->
  beforeEach ->
    # join時のレスポンス
    @JOIN_RESPONSE =
      message:
        done: false,
        room: '_100645059_-943718400',
        roomType: 1,
        roomTopic: undefined,
        user: {
          id: '_99999999_-9999999999',
          domainId: { high: 12345678, low: 12345678 },
          displayName: 'Sample Bot',
          canonicalDisplayName: 'Sample Bot',
          phoneticDisplayName: 'Sample Bot',
          canonicalPhoneticDisplayName: 'Sample Bot',
          updatedAt: { high: 336, low: -596682080 },
          email: 'bot@example.com',
          id_i64: { high: 99999999, low: -9999999999 },
          name: 'Sample Bot',
          profile_url: undefined,
          room: '_100645059_-943718400'
        }
        rooms: {
          '_100645059_-943718400': {
            id: '_100645059_-943718400',
            domainId: '_12345678_12345678',
            type: 1,
            # userIds: [Object],
            # updatedAt: [Object],
            leftUsers: null,
            # id_i64: [Object],
            topic: undefined,
            # users: [Object],
            # domain: [Object],
            # domainId_i64: [Object]
          },
          _101059552_499122176: {
            id: '_101059552_499122176',
            domainId: '_98765432_-9876543210',
            type: 1,
            # userIds: [Object],
            # updatedAt: [Object],
            leftUsers: null,
            # id_i64: [Object],
            topic: undefined,
            # users: [Object],
            # domain: [Object],
            # domainId_i64: [Object]
          }
        }
        roomUsers: [
          {
            id: '_11111111_-1111111111',
            displayName: 'John Doe',
            canonicalDisplayName: 'John Doe',
            profileImageUrl: 'https://api.direct4b.com/albero-app-server/files/-1WYhun2mcNlYyZ/F7EfkNYF7o',
            updatedAt: { high: 336, low: -628405646 },
            domainId: { high: 12345678, low: 12345678 },
            email: 'john@example.com',
            id_i64: { high: 11111111, low: -1111111111 },
            name: 'John Doe',
            profile_url: 'https://api.direct4b.com/albero-app-server/files/-1WYhun2mcNlYyZ/F7EfkNYF7o'
          },
          {
            id: '_99999999_-9999999999',
            domainId: { high: 12345678, low: 12345678 },
            displayName: 'Sample Bot',
            canonicalDisplayName: 'Sample Bot',
            phoneticDisplayName: 'Sample Bot',
            canonicalPhoneticDisplayName: 'Sample Bot',
            updatedAt: { high: 336, low: -596682080 },
            email: 'bot@example.com',
            id_i64: { high: 99999999, low: -9999999999 },
            name: 'Sample Bot',
            profile_url: undefined
          }
        ]

    # 通常のテキスト投稿のレスポンス
    @TEXT_RESPONSE =
      send: sinon.stub()
      message:
        text: 'Hubot ヘルプ',
        id: '_101222609_-2080374784',
        done: false,
        room: '_100645059_-943718400',
        roomType: 1,
        roomTopic: undefined,
        rooms: {
          '_100645059_-943718400': {
            id: '_100645059_-943718400',
            domainId: '_12345678_12345678',
            type: 1,
            # userIds: [Object],
            # updatedAt: [Object],
            leftUsers: null,
            # id_i64: [Object],
            topic: undefined,
            # users: [Object],
            # domain: [Object],
            # domainId_i64: [Object]
          },
          _101059552_499122176: {
            id: '_101059552_499122176',
            domainId: '_98765432_-9876543210',
            type: 1,
            # userIds: [Object],
            # updatedAt: [Object],
            leftUsers: null,
            # id_i64: [Object],
            topic: undefined,
            # users: [Object],
            # domain: [Object],
            # domainId_i64: [Object]
          }
        }
        user: {
          id: '_11111111_-1111111111',
          domainId: { high: 12345678, low: 12345678 },
          displayName: 'John Doe',
          canonicalDisplayName: 'John Doe',
          phoneticDisplayName: 'John Doe',
          canonicalPhoneticDisplayName: 'John Doe',
          updatedAt: { high: 336, low: -596682080 },
          email: 'bot@example.com',
          id_i64: { high: 99999999, low: -9999999999 },
          name: 'Sample Bot',
          profile_url: undefined,
          room: '_100645059_-943718400'
        }
        roomUsers: [
          {
            id: '_11111111_-1111111111',
            displayName: 'John Doe',
            canonicalDisplayName: 'John Doe',
            profileImageUrl: 'https://api.direct4b.com/albero-app-server/files/-1WYhun2mcNlYyZ/F7EfkNYF7o',
            updatedAt: { high: 336, low: -628405646 },
            domainId: { high: 12345678, low: 12345678 },
            email: 'john@example.com',
            id_i64: { high: 11111111, low: -1111111111 },
            name: 'John Doe',
            profile_url: 'https://api.direct4b.com/albero-app-server/files/-1WYhun2mcNlYyZ/F7EfkNYF7o'
          },
          {
            id: '_99999999_-9999999999',
            domainId: { high: 12345678, low: 12345678 },
            displayName: 'Sample Bot',
            canonicalDisplayName: 'Sample Bot',
            phoneticDisplayName: 'Sample Bot',
            canonicalPhoneticDisplayName: 'Sample Bot',
            updatedAt: { high: 336, low: -596682080 },
            email: 'bot@example.com',
            id_i64: { high: 99999999, low: -9999999999 },
            name: 'Sample Bot',
            profile_url: undefined
          }
        ]

    @robot =
      logger:
        debug: sinon.spy()
        info: sinon.spy()
        warning: sinon.spy()
        error: sinon.spy()

  afterEach ->
    # 環境変数を削除
    REQUIRED_ENVS = [
      'REDIS_URL'
      'SALESFORCE_CLIENT_ID'
      'SALESFORCE_CLIENT_SECRET'
      'SALESFORCE_REDIRECT_URI'
      'SALESFORCE_ORG_ID'
    ]
    for env in REQUIRED_ENVS
      delete process.env[env]

  describe "コンストラクタ", ->
    it "環境変数が設定されていないとエラー", ->
      constructor = ->
        new BotDockHelper(@robot)
      expect(constructor).to.throw 'REDIS_URL, SALESFORCE_CLIENT_ID, SALESFORCE_CLIENT_SECRET, SALESFORCE_REDIRECT_URI, SALESFORCE_ORG_ID must be specified.'
    
    it "環境変数が不足しているとエラー", ->
      process.env.REDIS_URL = 'redis://127.0.0.1:6379'
      process.env.SALESFORCE_CLIENT_ID = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      process.env.SALESFORCE_CLIENT_SECRET = '11111111110000'
      constructor = ->
        new BotDockHelper(@robot)
      expect(constructor).to.throw 'SALESFORCE_REDIRECT_URI, SALESFORCE_ORG_ID must be specified.'

    it "環境変数が設定されているとエラーにならない", ->
      process.env.REDIS_URL = 'redis://127.0.0.1:6379'
      process.env.SALESFORCE_CLIENT_ID = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      process.env.SALESFORCE_CLIENT_SECRET = '11111111110000'
      process.env.SALESFORCE_REDIRECT_URI = 'http://localhost:8888'
      process.env.SALESFORCE_ORG_ID = '*'
      constructor = ->
        new BotDockHelper(@robot)
      expect(constructor).not.to.throw /.*/

  describe "インスタンスメソッド", ->
    beforeEach ->
      process.env.REDIS_URL = 'redis://127.0.0.1:6379'
      process.env.SALESFORCE_CLIENT_ID = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      process.env.SALESFORCE_CLIENT_SECRET = '11111111110000'
      process.env.SALESFORCE_REDIRECT_URI = 'http://localhost:8888'
      process.env.SALESFORCE_ORG_ID = '*'
      @botdock = new BotDockHelper(@robot)
    
    describe "_generateSessionId" , ->
      it "33文字のランダムな文字列が生成される", ->
        id1 = @botdock._generateSessionId()
        id2 = @botdock._generateSessionId()
        expect(id1.length).to.eq 33
        expect(id2.length).to.eq 33
        expect(id1).to.not.eq id2

    describe "_getUserIdOnJoin", ->
      it "joinメッセージのときuserIdが取得できる", ->
        expect(@botdock._getUserIdOnJoin(@JOIN_RESPONSE)).to.eq '_11111111_-1111111111'

    describe "_getDomainId", ->
      it "ドメインIDが取得できる", ->
        expect(@botdock._getDomainId(@JOIN_RESPONSE)).to.eq '_12345678_12345678'
        expect(@botdock._getDomainId(@TEXT_RESPONSE)).to.eq '_12345678_12345678'

    describe "_findDB", ->
      beforeEach ->
        @botdock.client =
          connected: true
          multi: ->
          select: ->
          get: ->
          exec: ->
        @client = @botdock.client
        sinon.stub(@client, 'multi').returns(@client)
        sinon.stub(@client, 'select').returns(@client)
        sinon.stub(@client, 'get').returns(@client)

      it "キャッシュ済みだったらそのDBインデックスを返す", ->
        @botdock.redisDBMap['_12345678_12345678'] = 3
        @botdock._findDB(@TEXT_RESPONSE).then (result) ->
          expect(result).to.eq 3

      it "DBインデックスが1000以上だったらエラーになる", ->
        @botdock._findDB(@TEXT_RESPONSE, 1000)
          .then (result) ->
            expect(true).to.be.false
          .catch (err) ->
            expect(true).to.be.true

      it "Redisの処理でエラーが起きると、rejectする", ->
        sinon.stub @client, 'exec', (callback) ->
          callback 'error!', {}
        @botdock._findDB(@TEXT_RESPONSE)
          .then (result) ->
            expect(true).to.be.false
          .catch (err) ->
            expect(err).to.eq 'error!'

      it "初回アクセスで該当する組織IDが取得できると1を返す", ->
        sinon.stub @client, 'exec', (callback) ->
          callback false, [1, '_12345678_12345678']
        @botdock._findDB(@TEXT_RESPONSE)
          .then (result) ->
            expect(result).to.eq 1
          .catch (err) ->
            expect(true).to.be.false

      it "3回目のアクセスで該当する組織IDが取得できると3を返す", ->
        execStub = sinon.stub()
        sinon.stub @client, 'exec', (callback) ->
          callback false, execStub()
        execStub.onCall(0).returns [1, 'xxxxx']
        execStub.onCall(1).returns [1, 'xxxxx']
        execStub.returns [1, '_12345678_12345678']
        @botdock._findDB(@TEXT_RESPONSE)
          .then (result) ->
            expect(result).to.eq 3
          .catch (err) ->
            expect(true).to.be.false

    describe "sendAuthorizationUrl", ->
      beforeEach ->
        @botdock._findDB = sinon.stub().returns(Promise.resolve(3))
        @botdock.client0 =
          connected: true
          multi: ->
          hmset: ->
          expire: ->
          exec: ->
        @client0 = @botdock.client0

        sinon.stub(@client0, 'multi').returns(@client0)
        sinon.stub(@client0, 'hmset').returns(@client0)
        sinon.stub(@client0, 'expire').returns(@client0)

      it "resにユーザIDが含まれていない場合エラー", ->
        delete @TEXT_RESPONSE.message.user.id
        @botdock.sendAuthorizationUrl(@TEXT_RESPONSE)
        expect(@TEXT_RESPONSE.send).to.have.been.calledWith "不正な操作です。"

      it "グループトークの場合にログインできない旨のメッセージを表示", ->
        @TEXT_RESPONSE.message.roomType = 2
        @botdock.sendAuthorizationUrl(@TEXT_RESPONSE)
        expect(@TEXT_RESPONSE.send).to.have.been.calledWith "#{@TEXT_RESPONSE.message.user.name}さん\n
まだSalesforceへの認証ができていないため、ご利用いただけません。\n
まずペアトークで私に話しかけて認証をしてからご利用ください。"

      it "Redisがダウン中はその旨のメッセージを表示", ->
        @botdock.client0.connected = false
        @botdock.sendAuthorizationUrl(@TEXT_RESPONSE)
        expect(@TEXT_RESPONSE.send).to.have.been.calledWith "
現在メンテナンス中です。大変ご不便をおかけいたしますが、今しばらくお待ちください。"
      
      it "Redisへ正しいデータを保存すること", ->
        @botdock._generateSessionId = sinon.stub().returns('abcdefg')
        @botdock.sendAuthorizationUrl(@TEXT_RESPONSE).then =>
          expect(@client0.hmset).to.have.been.calledWithMatch 'abcdefg', {
            userId: '_11111111_-1111111111'
            db: 3
            orgId: '_12345678_12345678'
            sfOrgId: '*'
          }

      it "Redisへの保存処理が成功したら、ログインURLを表示", ->
        sinon.stub @client0, 'exec', (callback) ->
          callback false, [1, 1, 1]

        @oauth2 = @botdock.oauth2
        sinon.stub(@oauth2, 'getAuthorizationUrl').returns('http://login.example.com/')

        @botdock.sendAuthorizationUrl(@TEXT_RESPONSE).then =>
          expect(@TEXT_RESPONSE.send).to.have.been.calledWith "
このBotを利用するには、Salesforceにログインする必要があります。\n
以下のURLからSalesforceにログインしてください。\n
http://login.example.com/"

      it "Redisへの保存処理が失敗したら、その旨を表示", ->
        sinon.stub @client0, 'exec', (callback) ->
          callback 'error!', [1, 1, 1]

        @oauth2 = @botdock.oauth2
        sinon.stub(@oauth2, 'getAuthorizationUrl').returns('http://login.example.com/')

        @botdock.sendAuthorizationUrl(@TEXT_RESPONSE).then =>
          expect(@TEXT_RESPONSE.send).to.have.been.calledWith "ログインURLの生成に失敗しました。"

    describe "getJsforceConnection", ->
      beforeEach ->
        @botdock._findDB = sinon.stub().returns(Promise.resolve(3))
        @botdock.client =
          connected: true
          multi: ->
          select: ->
          hgetall: ->
          exec: ->
        @client = @botdock.client

        sinon.stub(@client, 'multi').returns(@client)
        sinon.stub(@client, 'select').returns(@client)
        sinon.stub(@client, 'hgetall').returns(@client)

      it "resにユーザIDが含まれていない場合エラー", ->
        delete @TEXT_RESPONSE.message.user.id
        @botdock.getJsforceConnection(@TEXT_RESPONSE)
        expect(@TEXT_RESPONSE.send).to.have.been.calledWith "不正な操作です。"

      it "Redisがダウン中はその旨のメッセージを表示", ->
        @botdock.client.connected = false
        @botdock.getJsforceConnection(@TEXT_RESPONSE)
        expect(@TEXT_RESPONSE.send).to.have.been.calledWith "
現在メンテナンス中です。大変ご不便をおかけいたしますが、今しばらくお待ちください。"

      it "Redisへの保存処理が失敗したらreject", ->
        sinon.stub @client, 'exec', (callback) ->
          callback 'error!', [1, {}]

        @botdock.getJsforceConnection(@TEXT_RESPONSE)
          .then (result) =>
            expect(true).to.be.false
          .catch (err) =>
            expect(err).to.eq 'error!'

      it "OAuth情報が取得できなかったらreject", ->
        sinon.stub @client, 'exec', (callback) ->
          callback false, [1, null]
        @botdock.sendAuthorizationUrl = sinon.spy()

        @botdock.getJsforceConnection(@TEXT_RESPONSE)
          .then (result) =>
            expect(true).to.be.false
          .catch (err) =>
            expect(err).to.eql {code:"NO_AUTH", message:"認証していません"}
            expect(@botdock.sendAuthorizationUrl).to.have.been.calledWith @TEXT_RESPONSE

      it "OAuth情報が取得できたらjsforce.Connectionを返す", ->
        sinon.stub @client, 'exec', (callback) ->
          callback false, [
            1,
            {
              instanceUrl: 'http://ap.example.com'
              accessToken: 'ACCESS'
              refreshToken: 'REFRESH'
            }
          ]

        @botdock.getJsforceConnection(@TEXT_RESPONSE)
          .then (result) =>
            expect(result).to.be.an.instanceof(jsforce.Connection)
            expect(result.instanceUrl).to.eq 'http://ap.example.com'
            expect(result.accessToken).to.eq 'ACCESS'
            expect(result.refreshToken).to.eq 'REFRESH'
            expect(result.oauth2).to.eq @botdock.oauth2
          .catch (err) =>
            expect(true).to.be.false

    describe "checkAuthenticationOnJoin", ->
      it "_getUserIdOnJoinで取得したユーザIDがgetJsConnectionに渡される", ->
        @botdock._getUserIdOnJoin = sinon.stub().returns('USERID')
        @botdock.getJsforceConnection = sinon.spy()
        @botdock.checkAuthenticationOnJoin(@TEXT_RESPONSE)
        expect(@botdock.getJsforceConnection).to.have.been.calledWithMatch @TEXT_RESPONSE, {
          userId: 'USERID'
          skipGroupTalkHelp:true
        }

    describe "logout", ->
      beforeEach ->
        @botdock._findDB = sinon.stub().returns(Promise.resolve(3))
        @botdock.client =
          connected: true
          multi: ->
          select: ->
          del: ->
          exec: ->
        @client = @botdock.client

        sinon.stub(@client, 'multi').returns(@client)
        sinon.stub(@client, 'select').returns(@client)
        sinon.stub(@client, 'del').returns(@client)

      it "グループトークの場合にログインできない旨のメッセージを表示", ->
        @TEXT_RESPONSE.message.roomType = 2
        @botdock.logout(@TEXT_RESPONSE)
        expect(@TEXT_RESPONSE.send).to.have.been.calledWith "グループトークではログアウトできません。"

      it "resにユーザIDが含まれていない場合エラー", ->
        delete @TEXT_RESPONSE.message.user.id
        @botdock.logout(@TEXT_RESPONSE)
        expect(@TEXT_RESPONSE.send).to.have.been.calledWith "不正な操作です。"

      it "Redisがダウン中はその旨のメッセージを表示", ->
        @botdock.client.connected = false
        @botdock.logout(@TEXT_RESPONSE)
        expect(@TEXT_RESPONSE.send).to.have.been.calledWith "
現在メンテナンス中です。大変ご不便をおかけいたしますが、今しばらくお待ちください。"

      it "Redisの削除処理が失敗したらエラーを表示", ->
        sinon.stub @client, 'exec', (callback) ->
          callback 'error!', [1, 1]

        @botdock.logout(@TEXT_RESPONSE)
          .then (result) =>
            expect(@TEXT_RESPONSE.send).to.have.been.calledWith "ログアウトに失敗しました。"
          .catch (err) =>
            expect(true).to.be.false

      it "Redisの削除処理が成功したらログアウトした旨を表示", ->
        sinon.stub @client, 'exec', (callback) ->
          callback false, [1, 1]
        @botdock.getJsforceConnection = sinon.spy()

        @botdock.logout(@TEXT_RESPONSE)
          .then (result) =>
            expect(@TEXT_RESPONSE.send).to.have.been.calledWith "ログアウトしました。"
            expect(@botdock.getJsforceConnection).to.have.been.calledWith @TEXT_RESPONSE
          .catch (err) =>
            expect(true).to.be.false


