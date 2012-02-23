puts = console.log
Taxi = require("./../lib/taxi")
Pathology = require("pathology")

{extend} = require("underscore")

Thing = Pathology.Object.extend()
Taxi.Mixin.extends(Thing)

exports.Taxi =
  setUp: (callback) -> 
    @thing = Thing.create()
    callback

  "trigger()":
    "simplest event triggers": (test) ->
      test.expect(1)
      @thing.bind "event", -> 
        test.ok()
        test.done()

