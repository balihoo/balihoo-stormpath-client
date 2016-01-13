
client = require '../lib/stormpath-client'
assert = require 'assert'

spc = new client
  id:'myid'
  secret:'mysecret'
  application_href:'myhref'
  idsite_callback:'myidhandler'
  organization_key: 'myorg'


describe 'handleIdSiteCallback', ->
  it 'rejects expired jwts', (done) ->
    exp = new Date()
    exp.setMinutes exp.getMinutes() - 1
    jwt = spc.jwt.create {}, exp
    spc.handleIdSiteCallback jwt, (err, verified) ->
      assert.strictEqual err.message, 'Jwt is expired'
      done()
  it 'rejects corrupted jwts', (done) ->
    jwt = spc.jwt.create foo:'bar'
    jwt += 'broken'
    spc.handleIdSiteCallback jwt, (err, verified) ->
      assert.strictEqual err.message, 'Signature verification failed'
      done()
  it 'rejects not AUTHENTICATED jwts', (done) ->
    jwt = spc.jwt.create status:'LOGOUT'
    spc.handleIdSiteCallback jwt, (err, verified) ->
      assert.strictEqual err.message, 'NOT AUTHENTICATED'
      done()
  it 'rejects jwts with any errors', (done) ->
    msg = 'foo'
    jwt = spc.jwt.create err:message:msg
    spc.handleIdSiteCallback jwt, (err, verified) ->
      assert.strictEqual err.message, msg
      done()
  it 'fetches userData and returns with the verified jwt', (done) ->
    jwt = spc.jwt.create
      status: 'AUTHENTICATED'
      foo:'bar'
    userData =
      brand: {'brand1':true,'brand2':true}
      arbitrary: 'result'
    username = 'test user'
    
    spc.getUserData = (sub, callback) -> callback null, username, userData

    spc.handleIdSiteCallback jwt, (err, verified) ->
      assert.ifError err
      assert.strictEqual verified.body.foo, 'bar'
      assert.strictEqual verified.body.username, username
      for key,val of userData
        assert.deepEqual verified.body.userdata[key], val
      done()