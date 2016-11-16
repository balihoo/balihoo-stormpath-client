rewire = require 'rewire'
client = rewire '../lib/stormpath-client'
assert = require 'assert'
sinon = require 'sinon'

spc = new client
  id:'myid'
  secret:'mysecret'
  application_href:'myhref'
  idsite_callback:'myidhandler'
  idsite_logouturl: 'mylogout'
  organization_key: 'myorg'

apiLRUCache = client.__get__ "apiLRUCache"
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

  fix.fakeRequest =
    url: fix.url
      headers:
        authorization: fix.auth
      method: fix.method

afterEach ->
  mocks.restore()



describe "authApiRequest", ->
  it "should return the value straight from cache if it is available", ->
    apiLRUCache.set "xxxxxx", "my value"
    spc.authApiRequest fix.fakeRequest
