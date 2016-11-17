hash = require 'object-hash'
client = require '../lib/stormpath-client'
assert = require 'assert'
sinon = require 'sinon'

spc = new client
  id:'myid'
  secret:'mysecret'
  application_href:'myhref'
  idsite_callback:'myidhandler'
  idsite_logouturl: 'mylogout'
  organization_key: 'myorg'

apiLRUCache = client.__testing.apiLRUCache
mocks = null
fix = {}


beforeEach ->
  mocks = sinon.sandbox.create()    # enables us to restore all mocks/spies in one go
  apiLRUCache.reset()

  fix =
    url: "some url"
    auth: "some auth string"
    method: "some method"
    callback: mocks.spy()
    cacheValue: "myValue"

  fix.fakeRequest =
    url: fix.url
    headers:
      authorization: fix.auth
    method: fix.method

  fix.hashKey = hash.MD5 fix.fakeRequest

afterEach ->
  mocks.restore()


describe "authApiRequest", ->
  it "should return the value straight from cache if it is available", ->
    apiLRUCache.set fix.hashKey, fix.cacheValue
    spc.authApiRequest fix.fakeRequest, fix.callback
    assert fix.callback.called
    assert.deepEqual fix.callback.firstCall.args, [null, fix.cacheValue]

  it "should fetch data from stormpath, set the cache and return expected value", ->
    