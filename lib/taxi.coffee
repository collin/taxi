Pathology = require "pathology"
module.exports = Taxi = Pathology.Namespace.create("Taxi")
{isString, concat, slice, toArray, pluck, indexOf, include, last, any} = require "underscore"

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
    console.log "addSegment", segment
    @segments.push _segment = Taxi.Segment.create(this, segment)
    _segment.rebind()
    _segment

  segmentsAfter: (segment) ->
    index = indexOf @segments, segment
    @segments[index+1..]

  readToSegment: (segment) ->
    index = indexOf @segments, segment   
    @root.readPath 
    target = @root
    properties = pluck(@segments[..index], 'value')
    # console.log "properties", properties
    for property in properties[..-2]
      # console.log "looping", property
      target = target?[property]?.get()

    # console.log "last", last(properties)
    # console.log "target", target

    return target?[last(properties)]

Taxi.Segment = Pathology.Object.extend
  initialize: (@path, @value) ->
    @namespace = "."+Pathology.id()
    @boundObjects = []

  binds: (source, event, callback) ->
    return unless source
    @boundObjects.push(source) unless include @boundObjects, source
    # console.log
    #   event: event
    #   namespace: @namespace
    #   handler: callback
    # #   context: this

    source.bind
      event: event
      namespace: @namespace
      handler: callback
      context: this

  rebind: ->
    console.log "rebind", @value
    @revokeBindings()
    @readSourceProperty()
    @applyBindings()

  revokeBindings: ->
    object.unbind(@namespace) for object in @boundObjects
    @boundObjects = []

  applyBindings: ->
    # console.log "applyBindings", @sourceProperty
    @binds @sourceProperty, 'change', @sourcePropertyChanged

  readSourceProperty: ->
    @sourceProperty = @path.readToSegment(this)

  isLastSegment: -> not any @followingSegments()

  sourcePropertyChanged: ->
    console.log "sourcePropertyChanged", @value
    console.log "isLastSegment", @isLastSegment()
    if @isLastSegment()
      @path.handler.call()
    else
      @rebind()
      segment.rebind() for segment in @followingSegments()

  followingSegments: ->
    @path.segmentsAfter(this)


Taxi.Mixin = Pathology.Mixin.create
  included: ->

  instance:
    bindPath: (path, handler) ->
      _path = Taxi.Path.create(this, handler)
      console.log "path", path
      _path.addSegment(segment) for segment in path
      _path

    property: (name) ->
      Taxi.Property.create(name, this)

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

Taxi.Property = Pathology.Property.extend
  Instance: Pathology.Property.Instance.extend
    set: (value) ->
      return value if value is @value
      @value = value
      @trigger "change"
      value

Taxi.Mixin.extends Taxi.Property.Instance


# This raises a question. At what level do we want to manage properties?
# This feels like the job of Pathology, but it would be something Pathology extends to other libraries
# to add to.

# On the other hand.
# This also raises the question of whether we mean to bubble events through Delegates

# in Stately we are
# delegate "component", to: "open_state"
# does this implies a bubbling of events

# we also fake has_many "active_states"

# Pasteup = BS.Namespace.create("Pasteup")
# Pasteup.Models = Pathology.Namespace.create()

# Things I would like to have be true.
#
# Element embeds_many State
# State embeds_many Components
# Component embeds Value
# Component belongs_to ComponentClass
# ComponentClass embeds Component

# Things to support:
# path = [css.Box, "width", "value"]
# element.set path, 20
# element.get path

# changepath = [css.Box, "width", "change:value"]
# element.bind changepath, -> console.log "YOU CHANGED THE VALUE!"

# # But we don't want to deal w/ figuring out how to bubble that shit, yo?
# # But we don't want to have WAY to many friggin' events firing all over the place.
# # Why not determine which events to trigger based on what paths are bound?

# class Model
#   @couldBe: (konstructor) ->
#     return true if this is konstructor
#     return true if konstructor in @descendants
#     return false

# BS.InvalidOptions = BS.Object.extend
#   constructor: (@errors) ->
#   errorMessages: ->
#     map @errors, (error) -> error.errorMessage()
#   toString: ->
#     @errorMessages().join("\n")

# BS.OptionValidator = BS.Object.extend
# BS.RequireOption = BS.OptionValidator.extend
#   constructor: (@name) ->
#   validate: (options) ->
#     if options[@name] then true else [false, this]
#   errorMessage: ->
#     "Option `#{name}' MUST be specified."

# BS.OptionValidation = BS.Mixin.create
#   mixed_in: ->
#     @class_inheritable_attr("validators", [])

#   class_methods: {}

#   validator: (name, constructor) ->
#     @class_methods[name] = ->
#       validator = constructor.create.apply(constructor, arguments)
#       @push_inheritable_item "validators", validator

# BS.OptionValidation.validator "require", BS.RequireOption

# class Property
#   BS.InheritableAttrs.extends(this)
#   BS.OptionValidation.extends(this)
#   BS.Delegate.extends(this)

#   @delegate "name", to: "config"
#   @require "name"

#   constructor: (@config) ->
#     @validate()

#   doesMatch: (piece) ->
#     return true if @name() is piece
#     return true if @model().couldBe(piece)
#     return false

#   validate: ->
#     errors = []
#     for validation in @validators
#       result = validation.validate(this.options)
#       continue if result is false
#       errors.push result[1]

#     return unless any(errors)

#     throw BS.InvalidOptions.create(errors)



# class Field extends Property
# class HasOne extends Property
# class EmbedsOne extends Property
# class HasMany extends Property
# class EmbedsMany extends Property
# class Virtual extends Property
# class Attribute extends Property





# class Element
#   @hasMany "components", model: -> css

