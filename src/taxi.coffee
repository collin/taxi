require "pathology"
require "underscore"
{clone, isArray, isString, concat, flatten, unique, map, unshift, invoke, compact,
slice, toArray, pluck, indexOf, include, last, any, isEqual, bind, each} = _

EVENT_NAMESPACER = /\.([\w-_]+)$/

Taxi = window.Taxi = Pathology.Namespace.new("Taxi")

# http://paulirish.com/2011/requestanimationframe-for-smart-animating/
# http://my.opera.com/emoller/blog/2011/12/20/requestanimationframe-for-smart-er-animating

# requestAnimationFrame polyfill by Erik Möller
# fixes from Paul Irish and Tino Zijdel
lastTime = 0
vendors = ["ms", "moz", "webkit", "o"]
x = 0

while x < vendors.length and not window.requestAnimationFrame
  window.requestAnimationFrame = window[vendors[x] + "RequestAnimationFrame"]
  window.cancelAnimationFrame = window[vendors[x] + "CancelAnimationFrame"] or window[vendors[x] + "CancelRequestAnimationFrame"]
  ++x
unless window.requestAnimationFrame
  window.requestAnimationFrame = (callback, element) ->
    currTime = new Date().getTime()
    timeToCall = Math.max(0, 16 - (currTime - lastTime))
    id = window.setTimeout(->
      callback currTime + timeToCall
    , timeToCall)
    lastTime = currTime + timeToCall
    id
unless window.cancelAnimationFrame
  window.cancelAnimationFrame = (id) ->
    clearTimeout id

NO_EVENT = toString: "NO_EVENT"
parseSpec = (raw) ->
 if isString(raw)
    string = raw
    spec = {}

    if string.match EVENT_NAMESPACER
      [name, namespace] = string.split(".")
      spec.event = if name then name else NO_EVENT
      spec.namespace = namespace
    else
      spec.event = string
      spec.namespace = "none"
  else if raw is undefined
    spec =
      namespace: "none"
      event: NO_EVENT
  else
    spec = raw
    spec.namespace = spec.namespace?.replace(/^\./, "") or "none"

  spec.event ?= NO_EVENT

  return spec

specParser = (fn) ->
  (rawSpec) ->
    parsedSpec = parseSpec(rawSpec)
    fn.apply this, [parseSpec(rawSpec), toArray(arguments)[1..]]

class Taxi.Spec
  def initialize: ({@event, @namespace, @context, @handler}) ->
  # @::initialize.doc =
  #   params: [
  #     ["spec", "Object", true]
  #   ]
  #   desc: """
  #     spec keys:
  #     <table>
  #       <tr><td>event</td><td></td></tr>
  #       <tr><td>namespace</td><td></td></tr>
  #       <tr><td>context</td><td></td></tr>
  #       <tr><td>handler</td><td></td></tr>
  #     </table>
  #   """

  def invoke: (_arguments) ->
    Taxi.Governer.react "#{@objectId()} #{_arguments.toString()}", =>
      @handler.apply(@context, _arguments)

  def invokeAsAll: (realEvent, _arguments) ->
    key = @context.objectId() + realEvent + _arguments.toString()
    Taxi.Governer.react key, =>
      @handler.apply(@context, _(clone _arguments).unshift(realEvent))

class Taxi.Path
  def initialize: (@root, @handler) ->
    @segments = new Array

  def inspect: ->
    "segments: " + _(@segments).pluck('value').join(",")

  def unbind: ->
    invoke @segments, 'revokeBindings'

  def addSegment: (segment) ->
    @segments.push( _segment = Taxi.Segment.new(this, segment) )
    _segment.rebind()
    _segment

  def connected: ->
    any @lastSegment().objects(@value)

  def lastSegment: ->
    _.last @segments

  def segmentBefore: (segment) ->
    index = indexOf @segments, segment
    @segments[ index - 1 ]

  def segmentAfter: (segment) ->
    index = indexOf @segments, segment
    @segments[ index + 1 ]

  def segmentsAfter: (segment) ->
    index = indexOf @segments, segment
    @segments[(index+1)..]

  def readToSegment: (segment) ->
    segment.readToSelf(@root, @segments)

class Taxi.Segment
  def inspect: ->
    "@value: #{@value}"

  def initialize: (@path, @value) ->
    @namespaces = Pathology.Map.new( -> Pathology.id() )
    @boundObjects = Pathology.Set.new()

  def root: -> @path.root

  def previousObjects: ->
    @path.segmentBefore(this)?.objects(@value) or [@root()]

  def properties: () ->
    properties = []
    objects = @previousObjects()
    for object in objects
      properties = properties.concat object.propertiesThatCouldBe(@value)

    properties

  def objects: ->
    return @_objects if @_objects
    @_objects = []
    for property in @properties()
      @_objects = @_objects.concat property.objects(@value)

    @_objects

  def applyBindings: (properties = @properties()) ->
    # console.log "applyBindings", @, properties
    for property in properties
      property.bindToPathSegment(this)
      @bindToObject(member) for member in property.members()

  def binds: (object, event, callback) ->
    namespace = @namespaces.get(object)
    @boundObjects.add(object)
    object.bind
      event: event
      namespace: namespace
      handler: callback
      context: this

  def rebind: ->
    [objects, @_objects] = [@_objects, undefined]
    return if isEqual objects, @objects() and objects isnt undefined
    #PERF AS.count("path rebind")
    @revokeBindings()
    @applyBindings()

  def revokeBindings: ->
    @boundObjects.each (object) =>
      namespace = @namespaces.get(object)
      object.unbind("."+namespace)

    @boundObjects.empty()

  def bindToObject: (object) ->
    @applyBindings object.propertiesThatCouldBe(@value)

  def revokeObjectBindings: (object) ->
    for property in object.propertiesThatCouldBe(@value)
      namespace = @namespaces.get(property)
      property.unbind("."+namespace)
      @boundObjects.del(property)

  def changeCallback: (item) ->
    # console.log "changeCallback", @, @path
    Taxi.Governer.once "#{@objectId()} change", =>
      if @path.segmentAfter(this)
        @rebind()
        segment.rebind() for segment in @path.segmentsAfter(this)
        last = @path.lastSegment()
        @path.handler(item) if _(last.objects()).any()
      else
        @path.handler(item)

  def insertCallback: (item, collection) ->
    Taxi.Governer.once "#{@objectId} insert #{item.objectId()}", =>
      return unless segment = @path.segmentAfter(this)
      segment.bindToObject(item)

  def removeCallback: (item, collection) ->
    Taxi.Governer.once "#{@objectId} remove #{item.objectId()}", =>
      return unless segment = @path.segmentAfter(this)
      segment.revokeObjectBindings(item)

class Taxi.Governer
  defs run: (fn) ->
    @enter()
    fn()
    @exit()

  defs once: (object, fn) ->
    return fn() unless @currentLoop
    return if @currentLoop.tainted(object)
    @currentLoop.taint(object)
    @schedule(fn)

  defs react: (object, fn) ->
    unless @currentLoop?
      @enter()
      setTimeout 0, bind( @exit, this )
    @once(object, fn)
  # @::react.doc =
  #   params: [
  #     ["object", "*", true]
  #     ["fn", "Function", true]
  #   ]
  #   desc: """
  #     May be called outside of a RunLoop. Creates a RunLoop if there
  #     isn't one. If a RunLoop is scheaduled from 'react', it is scheduled
  #     to exit as soon as control is handed back to the browser.
  #
  #     A likely use of 'react' is in response to a user initiated DOM
  #     event, such as a click. Arguments and handling of the callback
  #     are the same as in Taxi.Governer.once.
  #   """

  defs schedule: (fn) ->
    throw new Error "Cannot schedule a task unless a RunLoop is active." unless @currentLoop
    @currentLoop.schedule(fn)

  defs enter: ->
    throw new Error "Cannot enter a RunLoop while one is active." if @currentLoop
    @currentLoop = Taxi.Governer.RunLoop.new()

  defs exit: ->
    throw new Error "Cannot exit a RunLoop unless one is active." unless @currentLoop
    console.time("Exiting RunLoop")

    cancelAnimationFrame @currentAnimationFrame if @currentAnimationFrame
    @currentAnimationFrame = requestAnimationFrame =>
      @currentAnimationFrame = undefined
      unless @currentLoop
        console.warn "requestAnimationFrame with no currentLoop"
        return
      console.log "requestAnimationFrame"
      @_exit() while @currentLoop.any()
      @currentLoop = undefined
      console.timeEnd("Exiting RunLoop")

  defs _exit: ->
    [exitingLoop, @currentLoop] = [@currentLoop, undefined]
    @enter()
    exitingLoop.flush()

class Taxi.Governer.RunLoop
  def initialize: ->
    @_schedule = []
    @_taintedObjects = Pathology.Set.new()

  def taint: (object) ->
    @_taintedObjects.add(object)

  def tainted: (object) ->
    @_taintedObjects.include(object)

  def schedule: (fn) ->
    @_schedule.push fn

  def any: -> _.any @_schedule

  def flush: ->
    console.log "FLUSH"
    fn() for fn in @_schedule

module Taxi.Mixin
  defs property: (name) ->
    Taxi.Property.new(name, this)

  def bindPath: (path, handler) ->
    @pathBindings ?= []

    if isArray path[0]
      return Taxi.Detour.new(this, path, handler)
    else
      _path = Taxi.Path.new(this, handler)
      _path.addSegment(segment) for segment in path
      @pathBindings.push _path
      return _path

  def bind: specParser (spec, _arguments) ->
    @_callbacks ?= new Object
    spec.context ?= this
    spec.handler ?= _arguments[0]
    # TODO: ASSERT spec.handler
    # Pathology.assert MUST_HAVE_HANDLER, spec.handler

    @_callbacks[spec.event] ?= {}
    @_callbacks[spec.event][spec.namespace] ?= []
    @_callbacks[spec.event][spec.namespace].push Taxi.Spec.new(spec)

  def unbind: specParser (spec, _arguments) ->
    return unless @_callbacks
    if spec.namespace is 'none' and spec.event isnt NO_EVENT
      delete @_callbacks[spec.event]
    else if spec.namespace is 'none' and spec.event is NO_EVENT
      delete @_callbacks
    else if spec.namespace isnt 'none' and spec.event isnt NO_EVENT
      delete @_callbacks[spec.event][spec.namespace]
    else if spec.namespace isnt 'none' and spec.event is NO_EVENT
      for event, namespaces of @_callbacks
        delete namespaces[spec.namespace]

  def trigger: specParser (spec, _arguments) ->
    # TODO: throw error if attempting to trigger 'all'
    return unless @_callbacks
    if spec.namespace is 'none'
      for namespace, specs of @_callbacks[spec.event]
        _spec.invoke(_arguments) for _spec in specs

      for namespace, specs of @_callbacks.all ? []
        _spec.invokeAsAll(spec.event, _arguments) for _spec in specs

    else
      for _spec in @_callbacks[spec.event][spec.namespace]
        _spec.invoke(_arguments)

      for _spec in @_callbacks.all?[spec.namespace] ? []
        _spec.invokeAsAll(spec.event, _arguments)

    return undefined

class Taxi.Detour
  def initialize: (@root, @paths, @handler) ->
    @boundPaths = for path, index in @paths
      do (index) =>
        @root.bindPath path, => @handlerFor(index, @boundPaths, @handler)
  # @::initialize.doc =
  #   params: [
  #     ["@root", "Pathology.Object", true]
  #     ["@paths...", "Array", true]
  #     ["@handler", "Function", true]
  #   ]
  #   desc: """
  #
  #   """

  def handlerFor: (index, boundPaths, handler) ->
    unless index is 0
      for path, _index in boundPaths[0..index]
        continue if index is _index
        return if path.connected()
    handler()
  # @::handlerFor.doc =
  #   params: [
  #     ["index", "Number", true]
  #     ["bouthPaths", ["Taxi.Path"], true]
  #     ["handler", "Function", true]
  #   ]
  #   desc: """
  #     Iterates over all the bound paths with a higher priority.
  #     If any of them have 'connected' to an object we short-circuit.
  #     Otherwise we call the handler.
  #   """

  def unbind: ->
    invoke @boundPaths, 'unbind'
  # @::unbind.doc =
  #   desc: """
  #     Unbinds all paths in the detour.
  #   """

# Taxi.Detour.doc = """
#   Sometimes you have one callback that could follow two possible paths.
#   Also known as a detour.
#
#   An example of this would be a chain of command. During standard procedures
#    orders flow along the full chain of command. But under extreme
#     circumstances you might recieve an order directly from the general.
#     At that point you would prioritize your order from the general.
#
#   ```coffee
#     soldier = Army.Soldier.new()
#     emergency = ['general', 'standingOrder']
#     standard = ['officer', 'standingOrder']
#
#     Taxi.Detour.new soldier, emergency, standard, (-> console.log soldier.currentOrders() )
#   ```
#
# """

class Taxi.Map < Pathology.Map
  include Taxi.Mixin

  def set: (key, value) ->
    @_super.apply(this, arguments)
    @trigger "change", key, value
    value

# Specify on multiple lines to retain object paths.
Taxi.Property = Pathology.Property

class Taxi.Property.Instance < Pathology.Property.Instance
  include Taxi.Mixin

  def addDependant: (dependant) ->
    (@dependants ?= []).push dependant

  def triggerDependants: ->
    Taxi.Governer.react "#{@objectId()} triggerDependants", =>
      dependant.triggerFor() for dependant in (@dependants ? [])

  def bindToPathSegment: (segment) ->
    segment.binds this, "change", segment.changeCallback

  def objects: ->
    if @value then [@value] else []

  def members: -> []

  def set: (value) ->
    return value if value is @value
    oldvalue = @value
    @value = value
    @object.trigger("change")
    @object.trigger("change:#{@options.name}")
    @trigger "change", @value, oldvalue
    @triggerDependants()
    value



  