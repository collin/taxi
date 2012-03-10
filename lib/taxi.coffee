puts = console.log
Pathology = require "pathology"
Taxi = module.exports = Pathology.Namespace.new("Taxi")
{isString, concat, flatten, map, unshift, invoke, compact, slice, toArray, pluck, indexOf, include, last, any} = require "underscore"
_ = require("underscore")

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
    @handler.apply(@context, _(arguments).unshift(realEvent))

Taxi.Path = Pathology.Object.extend ({def}) ->
  def initialize: (@root, @handler) ->
    @segments = []

  def addSegment: (segment) ->
    # puts "addSegment", segment
    @segments.push _segment = Taxi.Segment.new(this, segment)
    _segment.rebind()
    _segment

  def segmentsAfter: (segment) ->
    index = indexOf @segments, segment
    @segments[index+1..]

  def readToSegment: (segment) ->
    index = indexOf @segments, segment   
    @root.readPath 
    targets = [@root]
    properties = pluck(@segments[..index], 'value')
    for property in properties[..-2]
      targets = compact flatten map targets, (target) -> 
        invoke target.propertiesThatCouldBe(property), 'get'

    lastSegment = last properties
    return (compact map targets, (target) -> target[lastSegment])

Taxi.Segment = Pathology.Object.extend ({def}) ->
  def initialize: (@path, @value) ->
    @namespace = "."+Pathology.id()
    @boundObjects = []

  def binds: (source, event, callback) ->
    return unless source
    @boundObjects.push(source) unless include @boundObjects, source

    source.bind
      event: event
      namespace: @namespace
      handler: callback
      context: this

  def rebind: ->
    @revokeBindings()
    @readSourceProperties()
    @applyBindings()

  def revokeBindings: ->
    object.unbind(@namespace) for object in @boundObjects
    @boundObjects = []

  def applyBindings: ->
    for property in @sourceProperties
      @binds property, 'change', @sourcePropertyChanged

  def readSourceProperties: ->
    @sourceProperties = @path.readToSegment(this)

  def isLastSegment: -> not any @followingSegments()

  def sourcePropertyChanged: ->
    if @isLastSegment()
      @path.handler.call()
    else
      @rebind()
      segment.rebind() for segment in @followingSegments()

  def followingSegments: ->
    @path.segmentsAfter(this)

Taxi.Mixin = Pathology.Module.extend ({def, defs}) ->
  defs included: ->

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
Taxi.Property = Pathology.Property.extend ->
  @Instance = Pathology.Property.Instance.extend ({def, include}) ->
    @include Taxi.Mixin

    def set: (value) ->
      return value if value is @value
      @value = value
      @trigger "change"
      value

