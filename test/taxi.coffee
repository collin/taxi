{extend} = _

NS = Pathology.Namespace.new("NS")
Evented = NS.Evented = Pathology.Object.extend()
Evented.include Taxi.Mixin
Evented.property("key")
End = NS.End = Evented.extend()
End.property("endkey")

module  "Taxi.bind()/trigger()"
test "trigger events without namespace", ->
  expect 3
  o = Evented.new()
  o.bind "event.namespace", -> ok true
  o.bind "event.namespace2", -> ok true
  o.bind "event", -> ok true
  o.trigger "event"
  Taxi.Governer.exit()

test "trigger events with namespace", ->
  expect 1
  o = Evented.new()
  o.bind "event2.namespace2", -> ok true
  o.bind "event.namespace2", -> ok true
  o.bind "event", -> ok true
  o.trigger "event.namespace2"
  Taxi.Governer.exit()

test "all events are triggerd on 'all' bindings", ->
  expect 3
  o = Evented.new()
  o.bind "all", -> ok true
  o.trigger "one"
  o.trigger "two"
  o.trigger "three"
  Taxi.Governer.exit()

test "'all' events pass through the real event name", ->
  expect 1
  o = Evented.new()
  o.bind "all", (realEvent) -> equal "mccoy", realEvent
  o.trigger("mccoy")
  Taxi.Governer.exit()

module  "unbind()"
test "unbind events without namespace", ->
  expect 1
  o = Evented.new()
  o.bind "event.namespace", -> ok true
  o.bind "event.namespace2", -> ok true
  o.bind "event", -> ok true
  o.unbind ".namespace2"
  o.unbind "event.namespace"
  o.trigger "event"
  o.trigger "event2"
  Taxi.Governer.exit()

test "unbind events with namespace", ->
  o = Evented.new()

  expect 2

  o.bind "event.namespace", -> ok true
  o.bind "event.namespace2", -> ok true
  o.bind "event", -> ok true

  o.unbind(".namespace2")
  o.trigger "event"
  Taxi.Governer.exit()

test "unbind all events", ->
  o = Evented.new()

  expect 1

  o.bind "event.namespace", -> ok true
  o.bind "event.namespace2", -> ok true
  o.bind "event", -> ok true

  o.unbind()
  o.trigger "event"
  # With no matching bindings for the trigger no RunLoop is scheduled.
  raises -> Taxi.Governer.exit()


module  "Map"
test "triggers on change", ->
  expect 1
  m = Taxi.Map.new()
  m.bind "change", (key, value) -> deepEqual ["key", "value"], [key, value]
  m.set "key", "value"
  Taxi.Governer.exit()

module  "Taxi property()"
# taxi overrides the default Pathology property with one that triggers events
test "triggers on change", ->
  expect 1
  o = Evented.new()
  o.key.bind "change", -> ok(true)
  o.key.set("value")
  Taxi.Governer.exit()

test "triggers events bound on a path", ->
  expect 1
  o = Evented.new()
  o.bindPath ['key'], -> ok(true)
  o.key.set("newvalue")
  Taxi.Governer.exit()


test "binds along nested path", ->
  expect(3)
  end = End.new()
  middle = Evented.new()
  root = Evented.new()

  middle.key.set end
  root.key.set middle

  end.bindPath ['endkey'], -> ok(true)
  middle.bindPath ['key', 'endkey'], -> ok(true)
  root.bindPath ['key', 'key', 'endkey'], -> ok(true)

  end.endkey.set("done")
  Taxi.Governer.exit()

test "and re-binds events when objects along the path change", ->
  expect 3

  root = Evented.new()
  a = Evented.new()
  b = Evented.new()
  end = End.new()

  path = root.bindPath ['key','key', 'endkey'], -> ok true

  # Each pass through the runloop should trigger the handler.
  root.key.set(a)
  a.key.set(end)
  end.endkey.set("foo")
  Taxi.Governer.exit()

  root.key.set(b)
  b.key.set(end)
  Taxi.Governer.exit()

  end.endkey.set("foo")
  end.endkey.set("bar")
  b.key.set(null)
  end.endkey.set("bazbat")
  Taxi.Governer.exit()


test "triggers event when last item is re-boud", ->
  expect 2

  root = Evented.new()
  a = Evented.new()
  b = Evented.new()
  end = End.new()
  end.endkey.set("ended")

  a.key.set(end)
  b.key.set(end)

  path = root.bindPath ['key','key', 'endkey'], -> ok true

  root.key.set(a)
  Taxi.Governer.exit()

  root.key.set(b)
  Taxi.Governer.exit()

module "Taxi.Detour"
test "triggers handler for first path in detour", ->
  expect 1

  root = Evented.new()
  end = End.new()
  a = End.new()

  root.key.set end
  end.endkey.set('ended')
  end.key.set(a)
  a.endkey.set('ended')

  path1 = [ 'key', 'endkey']
  path2 = ['key', 'key', 'endkey']

  root.bindPath([path1, path2], -> ok(true))

  a.endkey.set("ended again")    # set this twice to prove it is not triggering
  a.endkey.set("ended thrice")   # the handler
  end.endkey.set("ended again")  #
  Taxi.Governer.exit()


test "triggers handler for last path in detour when first path isn't connected", ->
  expect 1

  root = Evented.new()
  end = End.new()
  a = End.new()

  root.key.set end
  # end.endkey.set('ended')
  end.key.set(a)
  a.endkey.set('ended')

  path1 = [ 'key', 'endkey']
  path2 = ['key', 'key', 'endkey']

  root.bindPath([path1, path2], -> ok(true))

  end.trigger('change')   # set this twice to prove it is not triggering
  end.trigger('change')   # the handler
  a.endkey.set('ended again')

  Taxi.Governer.exit()
