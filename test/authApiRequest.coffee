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
    error: new Error "some thing went wrong"
    url: "some url"
    auth: "some auth string"
    method: "some method"
    callback: mocks.spy()
    cacheValue: "myValue"
    username: "username"
    userdata: "userdata"
    authResult:
      account:
        href: "href"

  fix.fakeRequest =
    url: fix.url
    headers:
      authorization: fix.auth
    method: fix.method
    otherStuff: "this will be stripped"

  fix.cleanRequest =
    url: fix.url
    headers:
      authorization: fix.auth
    method: fix.method

  fix.hashKey = hash.MD5 fix.cleanRequest

  # create mocked functions
  fix.application =
    authenticateApiRequest: () ->   # property needs to exist for stub call to work

  mocks.stub fix.application, "authenticateApiRequest", (request, callback) ->
    callback null, fix.authResult

  mocks.stub spc, "getApplication", (callback) ->
    callback null, fix.application

  mocks.stub spc, "getUserData", (authResult, callback) ->
    callback null, fix.username, fix.userdata

  mocks.spy apiLRUCache, "set"

afterEach ->
  mocks.restore()


describe "authApiRequest", ->
  context "value in cache", ->
    it "should return the value straight from cache if it is available", ->
      apiLRUCache.set fix.hashKey, fix.cacheValue
      spc.authApiRequest fix.fakeRequest, fix.callback
      assert fix.callback.calledOnce
      assert.deepEqual fix.callback.firstCall.args, [null, fix.cacheValue]

  context "value not in cache", ->
    it "should try to fetch the application", ->
      spc.authApiRequest fix.fakeRequest, fix.callback
      assert spc.getApplication.calledOnce

    it "should call callback with error if get application fails", ->
      spc.getApplication.restore()
      mocks.stub spc, "getApplication", (callback) ->
        callback fix.error
      spc.authApiRequest fix.fakeRequest, fix.callback
      assert.equal apiLRUCache.set.calledOnce, false
      assert fix.callback.calledOnce
      assert.deepEqual fix.callback.firstCall.args, [fix.error]

    it "should try to authenticate the api request", ->
      spc.authApiRequest fix.fakeRequest, fix.callback
      assert fix.application.authenticateApiRequest.calledOnce
      assert.deepEqual fix.application.authenticateApiRequest.firstCall.args[0], request: fix.cleanRequest

    it "should call callback with error if get authenticate fails", ->
      fix.application.authenticateApiRequest.restore()
      mocks.stub fix.application, "authenticateApiRequest", (request, callback) ->
        callback fix.error
      spc.authApiRequest fix.fakeRequest, fix.callback
      assert.equal apiLRUCache.set.calledOnce, false
      assert fix.callback.calledOnce
      assert.deepEqual fix.callback.firstCall.args, [fix.error]

    it "should call getUserData as expected", ->
      spc.authApiRequest fix.fakeRequest, fix.callback
      assert spc.getUserData.calledOnce
      assert spc.getUserData.firstCall.args[0], fix.authResult.account.href

    it "should call callback with error if getUserData fails", ->
      spc.getUserData.restore()
      mocks.stub spc, "getUserData", (authResult, callback) ->
        callback fix.error
      spc.authApiRequest fix.fakeRequest, fix.callback
      assert.equal apiLRUCache.set.calledOnce, false
      assert fix.callback.calledOnce
      assert.deepEqual fix.callback.firstCall.args, [fix.error]

    it "should try to add the expected result to the cache", ->
      spc.authApiRequest fix.fakeRequest, fix.callback
      assert apiLRUCache.set.calledOnce
      assert apiLRUCache.set.firstCall.args[0], [fix.hashKey, {username: fix.username, userdata: fix.userdata}]

    it "should return the correct value as expected", ->
      spc.authApiRequest fix.fakeRequest, fix.callback
      assert fix.callback.calledOnce
      assert.deepEqual fix.callback.firstCall.args, [null, {username: fix.username, userdata: fix.userdata}]


