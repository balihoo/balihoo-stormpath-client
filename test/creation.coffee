
stormpath_client = require '../lib/stormpath-client'
assert = require 'assert'

testJwtClient = (jwtClient, cb) ->
  jwt = jwtClient.create foo:'bar'
  jwtClient.verify jwt, (err, verified) ->
    assert.strictEqual verified.body.foo, 'bar'
    cb()

describe 'construction', ->
  config = null
  beforeEach ->
    config =
      id: 'myid'
      secret: 'mysecret'
      application_href: 'myhref'
      idsite_callback: 'mycallback'
      organization_key: 'myorg'
      
  describe 'stormpath-client', ->
    it 'requires a config object', (done) ->
      try
        spc = new stormpath_client()
        assert.fail 'error not thrown'
      catch e
        assert.strictEqual e.message, 'Missing config object'
        done()
    it 'requires config.id', (done) ->
      delete config.id
      try
        spc = new stormpath_client config
        assert.fail 'error not thrown'
      catch e
        assert.strictEqual e.message, "Missing constructor configuration parameter: id."
        done()
    it 'requires config.secret', (done) ->
      delete config.secret
      try
        spc = new stormpath_client config
        assert.fail 'error not thrown'
      catch e
        assert.strictEqual e.message, "Missing constructor configuration parameter: secret."
        done()
    it 'requires config.application_href', (done) ->
      delete config.application_href
      try
        spc = new stormpath_client config
        assert.fail 'error not thrown'
      catch e
        assert.strictEqual e.message, "Missing constructor configuration parameter: application_href."
        done()
    it 'requires config.idsite_callback', (done) ->
      delete config.idsite_callback
      try
        spc = new stormpath_client config
        assert.fail 'error not thrown'
      catch e
        assert.strictEqual e.message, "Missing constructor configuration parameter: idsite_callback."
        done()
    it 'requires config.idsite_callback', (done) ->
      delete config.organization_key
      try
        spc = new stormpath_client config
        assert.fail 'error not thrown'
      catch e
        assert.strictEqual e.message, "Missing constructor configuration parameter: organization_key."
        done()
    it 'succeeds when all config present', (done) ->
      spc = new stormpath_client config
      done()
  describe 'jwt', ->
    jwtErrorMessage = "Missing constructor configuration.\n" +
      "Constructor parameter is an object that must contain secret"
    it 'is accessible as an export without creating a stormpath client', (done) ->
      jwtClient = new stormpath_client.jwt config
      testJwtClient jwtClient, done
    it 'requires config', (done) ->
      try
        jwtClient = new stormpath_client.jwt()
        assert.fail 'error not thrown'
      catch e
        assert.strictEqual e.message, jwtErrorMessage
        done()
    it 'requires config.secret', (done) ->
      delete config.secret
      try
        jwtClient = new stormpath_client.jwt config
        assert.fail 'error not thrown'
      catch e
        assert.strictEqual e.message, jwtErrorMessage
        done()
    it 'is available as a property on the constructed stormpath client', (done) ->
      spc = new stormpath_client config
      testJwtClient spc.jwt, done


    