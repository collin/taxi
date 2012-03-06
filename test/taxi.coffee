puts = console.log
Taxi = require("./../lib/taxi")
Pathology = require("pathology")

{extend} = require("underscore")


NS = Pathology.Namespace.create("NS")
Evented = NS.Evented = Pathology.Object.extend()
Taxi.Mixin.extends(Evented)
Evented.property("key")

exports.Taxi =
  "bind()/trigger()":
    "trigger events without namespace": (test) ->
      test.expect 3
      o = Evented.create()
      o.bind "event.namespace", -> test.ok true
      o.bind "event.namespace2", -> test.ok true
      o.bind "event", -> test.ok true
      o.trigger "event"

      test.done()

    "trigger events with namespace": (test) ->
      test.expect 1
      o = Evented.create()
      o.bind "event2.namespace2", -> test.ok true
      o.bind "event.namespace2", -> test.ok true
      o.bind "event", -> test.ok true
      o.trigger "event.namespace2"

      test.done()

  "unbind()":
    "unbind events without namespace": (test) ->
      test.expect 1
      o = Evented.create()
      o.bind "event.namespace", -> test.ok true
      o.bind "event.namespace2", -> test.ok true
      o.bind "event", -> test.ok true
      o.unbind ".namespace2"
      o.unbind "event.namespace"
      o.trigger "event"
      o.trigger "event2"

      test.done()

    "unbind events with namespace": (test) ->
      o = Evented.create()

      test.expect 2

      o.bind "event.namespace", -> test.ok true
      o.bind "event.namespace2", -> test.ok true
      o.bind "event", -> test.ok true

      o.unbind(".namespace2")
      o.trigger "event"

      test.done()

    "unbind all events": (test) ->
      o = Evented.create()

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
      o = Evented.create()
      o.key.bind "change", -> test.ok(true); test.done()
      o.key.set("value")

  "bindPath()":
    "triggers events bound on a path": (test) ->
      o = Evented.create()
      path = o.bindPath ['key'], -> test.done()
      o.key.set("newvalue")

    "and re-binds events when objects along the path change": (test) ->
      test.expect 2

      root = Evented.create()
      a = Evented.create()
      b = Evented.create()
      End = Evented.extend()
      End.property("endkey")
      end = End.create()

      path = root.bindPath ['key','key', 'endkey'], -> test.ok true
      root.key.set(a)
      a.key.set(end)
      end.endkey.set("foo")

      root.key.set(b)
      b.key.set(end)
      end.endkey.set("foo")
      end.endkey.set("bar")

      test.done()

