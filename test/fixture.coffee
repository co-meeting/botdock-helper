sinon = require 'sinon'

module.exports =
  # join時のレスポンス
  join_response: ->
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
  text_response: ->
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

  robot: ->
    logger:
      debug: sinon.spy()
      info: sinon.spy()
      warning: sinon.spy()
      error: sinon.spy()
