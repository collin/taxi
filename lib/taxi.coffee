Pathology = require "pathology"
Taxi = module.exports = Pathology.Namespace.new("Taxi")
{isString, concat, flatten, unique, map, unshift, invoke, compact, slice, toArray, pluck, indexOf, include, last, any} = require "underscore"
_ = require("underscore")
puts = console.log

EVENT_NAMESPACER = /\.([\w-_]+)$/

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

  return spec

specParser = (fn) ->
  (rawSpec) ->
    parsedSpec = parseSpec(rawSpec)
    fn.apply this, [parseSpec(rawSpec), toArray(arguments)[1..]]

Taxi.Spec = Pathology.Object.extend ({def}) ->
  def initialize: (spec) ->
    {@path, @namespace, @context, @handler} = spec

  def invoke: (_arguments) ->
    @handler.apply(@context, _arguments)

  def invokeAsAll: (realEvent, _arguments) ->
    @handler.apply(@context, _(_arguments).unshift(realEvent))

Taxi.Path = Pathology.Object.extend ({def}) ->
  def initialize: (@root, @handler) ->
    @segments = new Array

  def addSegment: (segment) ->
    @segments.push( _segment = Taxi.Segment.new(this, segment) )
    _segment.rebind()
    _segment

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

Taxi.Segment = Pathology.Object.extend ({def}) ->
  def inspect: ->
    "@value: #{@value}"

  def initialize: (@path, @value) ->
    @namespaces = Pathology.Map.new( -> "."+Pathology.id() )
    @boundObjects = Pathology.Set.new()

  def root: -> @path.root
    
  def previousObjects: ->
    @path.segmentBefore(this)?.objects() or [@root()]
    
  def properties: () ->
    properties = []
    objects = @previousObjects()
    for object in objects
      properties = properties.concat object.propertiesThatCouldBe(@value)
    
    properties

  def objects: ->
    objects = []
    for property in @properties()
      objects = objects.concat property.objects()

    objects

  def applyBindings: (properties = @properties()) ->
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
    @revokeBindings()
    @applyBindings()

  def revokeBindings: ->
    @boundObjects.each (object) =>
      namespace = @namespaces.get(object)
      object.unbind(namespace)
    
    @boundObjects.empty()
    
  def bindToObject: (object) ->
    @applyBindings object.propertiesThatCouldBe(@value)

  def revokeObjectBindings: (object) ->
    for property in object.propertiesThatCouldBe(@value)
      namespace = @namespaces.get(property)
      property.unbind(namespace)
      @boundObjects.del(property)

  def changeCallback: ->
    if @path.segmentAfter(this)
      @rebind()
      segment.rebind() for segment in @path.segmentsAfter(this)
    else
      @path.handler()

  def insertCallback: (item, collection) ->
    return unless segment = @path.segmentAfter(this)
    segment.bindToObject(item)

  def removeCallback: (item, collection) ->
    return unless segment = @path.segmentAfter(this)
    segment.revokeObjectBindings(item)
    
Taxi.Mixin = Pathology.Module.extend ({def, defs}) ->
  defs property: (name) ->
    Taxi.Property.new(name, this)
      
  def bindPath: (path, handler) ->
    _path = Taxi.Path.new(this, handler)
    _path.addSegment(segment) for segment in path
    _path

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

# Specify on multiple lines to retain object paths.
Taxi.Property = Pathology.Property.extend ({delegate, include, def, defs}) ->

Taxi.Property.Instance = Pathology.Property.Instance.extend ({delegate, include, def, defs}) ->
  include Taxi.Mixin

  def bindToPathSegment: (segment) ->
    segment.binds this, "change", segment.changeCallback

  def objects: ->
    if @value then [@value] else []

  def members: -> []

  def set: (value) ->
    return value if value is @value
    @value = value
    @trigger "change"
    value

      

  