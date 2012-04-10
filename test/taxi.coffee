puts = console.log
Taxi = require("./../lib/taxi")
Pathology = require("pathology")
require('console-trace')

{extend} = require("underscore")


NS = Pathology.Namespace.new("NS")
Evented = NS.Evented = Pathology.Object.extend()
Evented.include Taxi.Mixin
Evented.property("key")

exports.Taxi =
  "bind()/trigger()":
    "trigger events without namespace": (test) ->
      test.expect 3
      o = Evented.new()
      o.bind "event.namespace", -> test.ok true
      o.bind "event.namespace2", -> test.ok true
      o.bind "event", -> test.ok true
      o.trigger "event"

      test.done()

    "trigger events with namespace": (test) ->
      test.expect 1
      o = Evented.new()
      o.bind "event2.namespace2", -> test.ok true
      o.bind "event.namespace2", -> test.ok true
      o.bind "event", -> test.ok true
      o.trigger "event.namespace2"

      test.done()

    "all events are triggerd on 'all' bindings": (test) ->
      test.expect 3
      o = Evented.new()
      o.bind "all", -> test.ok true
      o.trigger "one"
      o.trigger "two"
      o.trigger "three"
      test.done()

    "'all' events pass through the real event name": (test) ->
      test.expect 1
      o = Evented.new()
      o.bind "all", (realEvent) -> test.equal "mccoy", realEvent
      o.trigger("mccoy")
      test.done()

  "unbind()":
    "unbind events without namespace": (test) ->
      test.expect 1
      o = Evented.new()
      o.bind "event.namespace", -> test.ok true
      o.bind "event.namespace2", -> test.ok true
      o.bind "event", -> test.ok true
      o.unbind ".namespace2"
      o.unbind "event.namespace"
      o.trigger "event"
      o.trigger "event2"

      test.done()

    "unbind events with namespace": (test) ->
      o = Evented.new()

      test.expect 2

      o.bind "event.namespace", -> test.ok true
      o.bind "event.namespace2", -> test.ok true
      o.bind "event", -> test.ok true

      o.unbind(".namespace2")
      o.trigger "event"

      test.done()

    "unbind all events": (test) ->
      o = Evented.new()

      test.expect 0

      o.bind "event.namespace", -> test.ok true
      o.bind "event.namespace2", -> test.ok true
      o.bind "event", -> test.ok true

      o.unbind()
      o.trigger "event"

      test.done()

  "property()":
    # taxi overrides the default Pathology property with one that triggers events
    "triggers on change": (test) ->
      test.expect 1
      o = Evented.new()
      o.key.bind "change", -> test.ok(true); test.done()
      o.key.set("value")

  "bindPath()":
    "triggers events bound on a path": (test) ->
      o = Evented.new()
      o.bindPath ['key'], -> test.done()
      o.key.set("newvalue")

     "binds along nested path": (test) ->
        test.expect(3)
        End = NS.End = Evented.extend()
        End.property("endkey")

        end = End.new()
        middle = Evented.new()
        root = Evented.new()
        
        middle.key.set end
        root.key.set middle

        end.bindPath ['endkey'], -> test.ok(true)
        middle.bindPath ['key', 'endkey'], -> test.ok(true)
        root.bindPath ['key', 'key', 'endkey'], -> test.ok(true)
        
        end.endkey.set("done")
        test.done()


    "and re-binds events when objects along the path change": (test) ->
      test.expect 2

      root = Evented.new()
      a = Evented.new()
      b = Evented.new()
      End = Evented.extend()
      End.property("endkey")
      end = End.new()

      path = root.bindPath ['key','key', 'endkey'], -> test.ok true
      root.key.set(a)
      a.key.set(end)
      end.endkey.set("foo")

      root.key.set(b)
      b.key.set(end)
      end.endkey.set("foo")
      end.endkey.set("bar")
      b.key.set(null)
      end.endkey.set("bazbat")

      test.done()

