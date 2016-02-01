
client = require '../lib/stormpath-client'
assert = require 'assert'

spc = new client
  id:'myid'
  secret:'mysecret'
  application_href:'myhref'
  idsite_callback:'myidhandler'
  idsite_logouturl: 'mylogout'
  organization_key: 'myorg'


describe 'handleIdSiteLogout', ->
  it 'rejects expired jwts', (done) ->
    exp = new Date()
    exp.setMinutes exp.getMinutes() - 1
    jwt = spc.jwt.create {}, exp
    spc.handleIdSiteLogout jwt, (err, verified) ->
      assert.strictEqual err.message, 'Jwt is expired'
      done()
  it 'rejects corrupted jwts', (done) ->
    jwt = spc.jwt.create foo:'bar'
    jwt += 'broken'
    spc.handleIdSiteLogout jwt, (err, verified) ->
      assert.strictEqual err.message, 'Signature verification failed'
      done()
  it 'rejects not LOGOUT jwts', (done) ->
    jwt = spc.jwt.create status:'AUTHENTICATED'
    spc.handleIdSiteLogout jwt, (err, verified) ->
      assert.strictEqual err.message, 'NOT LOGGED OUT'
      done()
  it 'rejects jwts with any errors', (done) ->
    msg = 'foo'
    jwt = spc.jwt.create err:message:msg
    spc.handleIdSiteLogout jwt, (err, verified) ->
      assert.strictEqual err.message, msg
      done()
  it 'calls callback with null if no errors', (done) ->
    jwt = spc.jwt.create
      status: 'LOGOUT'

    spc.handleIdSiteLogout jwt, (err) ->
      assert.ifError err
      done()