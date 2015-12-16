

client = require '../lib/stormpath-client'
assert = require 'assert'

describe 'login tasks', ->
  describe 'getIdSiteUrl', (done) ->
    #todo: mock stormpath and write tests