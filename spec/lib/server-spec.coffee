EventEmitter = require('events').EventEmitter

describe 'Server', ->

  date = new Date

  Given ->
    @Message = class Message
      constructor: () ->
        if not (@ instanceof Message)
          return new Message
        @data =
          actor: 'me'
          action: 'say'
          content: 'hello'
          target: 'you'
          created: date
          id: 2
          reference: 1
          published: undefined

  Given ->
    @Sio = class Sio extends EventEmitter
      constructor: ->
        if not (@ instanceof Sio)
          return new Sio
      listen: ->

  Given ->
    @Builder = class Builder extends EventEmitter
      constructor: ->
        if not (@ instanceof Builder)
          return new Builder
      data: ->
        actor: 'me'
        action: 'say'
        content: 'hello'
        target: 'you'
        created: date
      deliver: ->

  Given ->
    @Handler = class Handler extends EventEmitter
      constructor: ->
        if not (@ instanceof Handler)
          return new Handler
      handle: (message) ->
      fn: ->

  Given ->
    @Receiver = class Receiver extends EventEmitter
      constructor: ->
        if not (@ instanceof Receiver)
          return new Receiver
      use: ->
      onReceive: ->


  Given ->
    @SocketMessages = class SocketMessages extends EventEmitter
      constructor: ->
      attach: ->
      actor: (a, b) -> b null, a.id
      target: (a,b,c) -> c null, b
      dettach: ->
      action: ->
      exchange: -> @ee
      ee: new EventEmitter
    @SocketMessages.make = ->
      return new SocketMessages

  Given ->
    @MessageExchange = class MessageExchange extends EventEmitter
      constructor: ->
        @ee = new EventEmitter
        @h = new EventEmitter
        @q = new EventEmitter
        @p = new EventEmitter
      publish: ->
      handler: -> @h
      queue: -> @q
      pubsub: -> @p
      channel: -> @ee
    @MessageExchange.Queue = class Queue extends EventEmitter
    @MessageExchange.PubSub = class PubSub extends EventEmitter
    @MessageExchange.make = ->
      return new MessageExchange

  Given ->
    @Server = requireSubject 'lib/server', {
      'socket.io': @Sio
      './message': @Message
      './builder': @Builder
      './handler': @Handler
      './receiver': @Receiver
      'socket-messages': @SocketMessages
      'message-exchange': @MessageExchange
    }

  Given -> @bus = @Server()
  Then -> expect(@Server.Exchange).toEqual @MessageExchange

  describe '#', ->
    
    Then -> expect(@bus instanceof @Server).toBe true

  describe '#listen', ->

    context 'with port', ->

      Given -> @port = 3000
      Given -> spyOn(@bus.io(),['listen'])
      When -> @bus.listen @port
      Then -> expect(@bus.io().listen).toHaveBeenCalled()

    context 'socket.io instance', ->

      Given -> @io = @Sio()
      Given -> spyOn(@io,['listen'])
      When -> @bus.listen @io
      Then -> expect(@bus.io()).toEqual @io

    xcontext 'with server', ->

      Given -> @server = require('http').createServer (req, res) ->
      Given -> @spyOn(@server,['on'])
      When -> @bus.listen @server
      Then -> expect(@server.on).toHaveBeenCalled()

  describe '#message', ->

    Given ->
      @params =
        actor: 'me'
        action: 'say'
        content: 'hello'
        target: 'you'
        created: date
    When -> @message = @bus.message @params
    Then -> expect(@message.data()).toEqual @params
    And -> expect(@message.listeners('built').length).toBe 1
    And -> expect(@message.listeners('built')[0]).toEqual @bus.onPublish

  describe '#messageExchange', ->

    Given -> @exchange = new @MessageExchange
    When -> @res = @bus.messageExchange(@exchange).messageExchange()
    Then -> expect(@res).toEqual @exchange

  describe '#exchange', ->

    Given -> @exchange = new @MessageExchange
    When -> @res = @bus.exchange(@exchange).exchange()
    Then -> expect(@res).toEqual @exchange

  describe '#socketMessages', ->

    Given -> @socketMessages = new @SocketMessages
    Given -> spyOn(@socketMessages.exchange(),['on']).andCallThrough()
    When -> @res = @bus.socketMessages(@socketMessages).socketMessages()
    Then -> expect(@res).toEqual @socketMessages
    And -> expect(@socketMessages.exchange().on).toHaveBeenCalledWith 'message', @bus.onMessage

  describe '#io', ->

    Given -> spyOn(@bus.socketMessages(),['attach']).andCallThrough()
    Given -> @io = @Sio()
    When -> @res = @bus.io(@io).io()
    Then -> expect(@res).toEqual @io
    And -> expect(@bus.socketMessages().attach).toHaveBeenCalledWith @io

  describe '#on', ->
    Given -> @fn = ->
    Given -> spyOn(@bus.exchange().handler(),['on']).andCallThrough()
    Given -> spyOn(@bus.socketMessages(),['action']).andCallThrough()
    When -> @bus.on 'name', @fn
    Then -> expect(@bus.exchange().handler().on).toHaveBeenCalled()
    And -> expect(@bus.exchange().handler().on.mostRecentCall.args[0]).toBe 'name'
    And -> expect(typeof @bus.exchange().handler().on.mostRecentCall.args[1]).toBe 'function'
    And -> expect(@bus.socketMessages().action).toHaveBeenCalledWith 'name'

  describe '#onPublish', ->

    context 'published', ->

      Given ->
        @message = @Message()
        @message.data.published = date
      Given -> spyOn(@bus.exchange(),['publish']).andCallThrough()
      When -> @bus.onPublish @message
      Then -> expect(@bus.exchange().publish).toHaveBeenCalledWith @message.data, @message.data.target

   context 'unpublished', ->
      
      Given -> @message = @Message()
      Given -> spyOn(@bus.exchange(),['publish']).andCallThrough()
      When -> @bus.onPublish @message
      Then -> expect(@bus.exchange().publish).toHaveBeenCalledWith @message.data

  describe '#onConnection', ->

    Given ->
      @socket = new EventEmitter
      @socket.id = 'me'
    Given -> spyOn(@bus.socketMessages(),['actor']).andCallThrough()
    Given -> spyOn(@bus.exchange(),['channel']).andCallThrough()
    Given -> spyOn(@bus.exchange().channel('me'),['on']).andCallThrough()
    Given -> spyOn(@socket,['on']).andCallThrough()
    When -> @bus.onConnection @socket
    Then -> expect(@bus.socketMessages().actor).toHaveBeenCalledWith @socket, jasmine.any(Function)
    And -> expect(@bus.exchange().channel).toHaveBeenCalledWith 'me'
    And -> expect(@bus.exchange().channel('me').on).toHaveBeenCalledWith 'message', jasmine.any(Function)
    And -> expect(@socket.on).toHaveBeenCalledWith 'disconnect', jasmine.any(Function)

  describe '#onError', ->
    Given -> spyOn(console,['error'])
    When -> @bus.onError 'message'
    Then -> expect(console.error).toHaveBeenCalledWith 'message'

  describe '#onMessage', ->

    Given -> @message = actor: 'me', action: 'say', content: 'hello', target: 'you'
    Given -> @socket = new EventEmitter
    Given -> spyOn(@bus,['emit']).andCallThrough()
    When -> @bus.onMessage @message, @socket
    Then -> expect(@bus.emit).toHaveBeenCalledWith 'from socket', @message, @socket

  describe '#onReceivedExchange', ->

    Given -> @message = new Message
    Given -> @socket = new EventEmitter
    When -> @bus.onReceivedExchange @message, @socket
    And -> expect(@socket.emit).toHaveBeenCalledWith @message.data.action, @message.data.actor, @message.data.content, @message.data.target, @message.data.created

  describe '#onReceivedSocket', ->

    Given -> @message = actor: 'me', action: 'say', content: 'hello', target: 'you'
    Given -> @builder = new @Builder
    Given -> spyOn(@builder,['deliver']).andCallThrough()
    Given -> spyOn(@bus,['message']).andCallThrough().andReturn(@builder)
    When -> @bus.onReceivedSocket @message
    Then -> expect(@bus.message).toHaveBeenCalled()
    And -> expect(@builder.deliver).toHaveBeenCalled()

  describe '#actor', ->

    Given -> spyOn(@bus.socketMessages(),['actor'])
    When -> @bus.actor()
    Then -> expect(@bus.socketMessages().actor).toHaveBeenCalled()

  describe '#target', ->

    Given -> spyOn(@bus.socketMessages(),['target'])
    When -> @bus.target()
    Then -> expect(@bus.socketMessages().target).toHaveBeenCalled()

  describe '#exchangeReceiver', ->

    Given -> spyOn(@bus,['addListener']).andCallThrough()
    Given -> @receiver = @Receiver()
    Given -> spyOn(@receiver,['addListener']).andCallThrough()
    When -> @res = @bus.exchangeReceiver(@receiver).exchangeReceiver()
    Then -> expect(@res).toEqual @receiver
    And -> expect(@receiver.addListener).toHaveBeenCalledWith 'error', @bus.onError
    And -> expect(@bus.addListener).toHaveBeenCalledWith 'from exchange', @receiver.onReceive

  describe '#socketReceiver', ->

    Given -> spyOn(@bus,['addListener']).andCallThrough()
    Given -> @receiver = @Receiver()
    Given -> spyOn(@receiver,['addListener']).andCallThrough()
    When -> @res = @bus.socketReceiver(@receiver).socketReceiver()
    Then -> expect(@res).toEqual @receiver
    And -> expect(@receiver.addListener).toHaveBeenCalledWith 'error', @bus.onError
    And -> expect(@bus.addListener).toHaveBeenCalledWith 'from socket', @receiver.onReceive

  describe '#in', ->

    Given -> spyOn(@bus,['exchangeReceiver']).andCallThrough()
    Given -> spyOn(@bus.exchangeReceiver(),['use']).andCallThrough()
    Given -> @fn = (a, b, c) ->
    When -> @bus.in @fn
    Then -> expect(@bus.exchangeReceiver).toHaveBeenCalled()
    And -> expect(@bus.exchangeReceiver().use).toHaveBeenCalledWith @fn

  describe '#out', ->

    Given -> spyOn(@bus,['socketReceiver']).andCallThrough()
    Given -> spyOn(@bus.socketReceiver(),['use']).andCallThrough()
    Given -> @fn = (a, b, c) ->
    When -> @bus.out @fn
    Then -> expect(@bus.socketReceiver).toHaveBeenCalled()
    And -> expect(@bus.socketReceiver().use).toHaveBeenCalledWith @fn

  describe '#socket', ->

    Given -> @socket = new EventEmitter
    Given -> @fn = jasmine.createSpy()
    Given -> @bus.socket @fn
    When -> @bus.io().emit 'connection', @socket
    Then -> expect(@fn).toHaveBeenCalledWith @socket, @bus

  describe '#alias', ->

    Given -> @name = 'me'
    Given -> @socket = new EventEmitter
    Given -> @socket.id = 'you'
    Given -> spyOn(@bus.exchange(),['channel']).andCallThrough()
    Given -> spyOn(@bus.exchange().channel(@name),['on']).andCallThrough()
    Given -> spyOn(@socket,['on']).andCallThrough()
    When -> @bus.alias @socket, @name
    Then -> expect(@bus.exchange().channel).toHaveBeenCalledWith @name
    And -> expect(@bus.exchange().channel(@name).on).toHaveBeenCalledWith 'message', jasmine.any(Function)
    And -> expect(@socket.on).toHaveBeenCalledWith 'disconnect', jasmine.any(Function)

    context 'triggering an event', ->
    
      Given -> @message = @Message()
      Given -> @message.data.target = @name
      Given -> spyOn(@bus,['emit']).andCallThrough()
      When -> @bus.exchange().channel(@name).emit 'message', @message
      Then -> expect(@bus.emit).toHaveBeenCalledWith 'from exchange', @message, @socket

    context 'soscket disconnect', ->

      When -> @socket.emit 'disconnect'
      Then -> expect(@bus.exchange().channel(@name).listeners('message').length).toBe 0

  describe '#queue', ->

    Given -> spyOn(@bus.exchange(),['queue']).andCallThrough()
    When -> @bus.queue()
    Then -> expect(@bus.exchange().queue).toHaveBeenCalled()

    context 'queue:Queue', ->

      Given -> @q = new @MessageExchange.Queue
      When -> @bus.queue(@q)
      Then -> expect(@bus.exchange().queue).toHaveBeenCalledWith @q

  describe '#pubsub', ->

    Given -> spyOn(@bus.exchange(),['pubsub']).andCallThrough()
    When -> @bus.pubsub()
    Then -> expect(@bus.exchange().pubsub).toHaveBeenCalled()

    context 'pubsub:PubSub', ->

      Given -> @q = new @MessageExchange.PubSub
      When -> @bus.pubsub(@q)
      Then -> expect(@bus.exchange().pubsub).toHaveBeenCalledWith @q
