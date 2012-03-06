puts = console.log
Pathology = require "pathology"
Taxi = module.exports = Pathology.Namespace.create("Taxi")
{isString, concat, flatten, map, invoke, compact, slice, toArray, pluck, indexOf, include, last, any} = require "underscore"

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

Taxi.Spec = Pathology.Object.extend
  initialize: (spec) ->
    {@path, @namespace, @context, @handler} = spec

  invoke: (_arguments) ->
    @handler.apply(@context, _arguments)

Taxi.Path = Pathology.Object.extend
  initialize: (@root, @handler) ->
    @segments = []

  addSegment: (segment) ->
    # puts "addSegment", segment
    @segments.push _segment = Taxi.Segment.create(this, segment)
    _segment.rebind()
    _segment

  segmentsAfter: (segment) ->
    index = indexOf @segments, segment
    @segments[index+1..]

  readToSegment: (segment) ->
    index = indexOf @segments, segment   
    @root.readPath 
    targets = [@root]
    properties = pluck(@segments[..index], 'value')
    for property in properties[..-2]
      targets = compact flatten map targets, (target) -> 
        invoke target.propertiesThatCouldBe(property), 'get'

    lastSegment = last properties
    return (compact map targets, (target) -> target[lastSegment])

Taxi.Segment = Pathology.Object.extend
  initialize: (@path, @value) ->
    @namespace = "."+Pathology.id()
    @boundObjects = []

  binds: (source, event, callback) ->
    return unless source
    @boundObjects.push(source) unless include @boundObjects, source

    source.bind
      event: event
      namespace: @namespace
      handler: callback
      context: this

  rebind: ->
    @revokeBindings()
    @readSourceProperties()
    @applyBindings()

  revokeBindings: ->
    object.unbind(@namespace) for object in @boundObjects
    @boundObjects = []

  applyBindings: ->
    for property in @sourceProperties
      @binds property, 'change', @sourcePropertyChanged

  readSourceProperties: ->
    @sourceProperties = @path.readToSegment(this)

  isLastSegment: -> not any @followingSegments()

  sourcePropertyChanged: ->
    if @isLastSegment()
      @path.handler.call()
    else
      @rebind()
      segment.rebind() for segment in @followingSegments()

  followingSegments: ->
    @path.segmentsAfter(this)

Taxi.Mixin = Pathology.Mixin.create
  included: ->

  static:
    property: (name) ->
      Taxi.Property.create(name, this)
      
  instance:
    bindPath: (path, handler) ->
      _path = Taxi.Path.create(this, handler)
      _path.addSegment(segment) for segment in path
      _path


    bind: specParser (spec, _arguments) ->
      @_callbacks ?= new Object
      spec.context ?= this
      spec.handler ?= _arguments[0]
      # TODO: ASSERT spec.handler
      # Pathology.assert MUST_HAVE_HANDLER, spec.handler
      
      @_callbacks[spec.event] ?= {}
      @_callbacks[spec.event][spec.namespace] ?= []
      @_callbacks[spec.event][spec.namespace].push Taxi.Spec.create(spec)

    unbind: specParser (spec, _arguments) ->
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

    trigger: specParser (spec, _arguments) ->
      return unless @_callbacks
      if spec.namespace is 'none'
        for namespace, specs of @_callbacks[spec.event]
          _spec.invoke(_arguments) for _spec in specs
      else
        for _spec in @_callbacks[spec.event][spec.namespace]
          _spec.invoke(_arguments)

# Specify on multiple lines to retain object paths.
Taxi.Property = Pathology.Property.extend()
Taxi.Property.Instance = Pathology.Property.Instance.extend
  set: (value) ->
    return value if value is @value
    @value = value
    @trigger "change"
    value

Taxi.Mixin.extends Taxi.Property.Instance
