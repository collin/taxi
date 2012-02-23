Pathology = require "pathology"
module.exports = Taxi = Pathology.Namespace.create("Taxi")

Taxi.Mixin = Pathology.Mixin.create
  included: ->

  instance:
    bind: (spec) ->
    unbind: (spec) ->
    trigger: (spec) ->


# Taxi.Event = Pathology.Object.extend()
# Taxi.Callbacks = Pathology.Object.extend()

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

