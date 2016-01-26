jwtLib = require '../lib/jwt'
assert = require 'assert'

spJwt = new jwtLib secret:'mysecret'

objectToBase64 = (o) ->
  s = JSON.stringify o
  new Buffer(s).toString 'base64'
base64ToObject = (b64) ->
  s = new Buffer(b64, 'base64').toString()
  JSON.parse s
extendBase64Object = (b64, extend) ->
  o = base64ToObject b64
  for key,val of extend
    o[key] = val
  objectToBase64 o

describe 'jwt', ->
  it 'can create a jwt from claims', ->
    jwt = spJwt.create {foo: 'bar'}
    assert.strictEqual typeof jwt, 'string'
    assert.strictEqual jwt.match(/\./g).length, 2
  it 'can verify a jwt string and return as an object', (done) ->
    claims = name:'Sparky', dog:true
    jwt = spJwt.create claims
    spJwt.verify jwt, (err, verified) ->
      assert.strictEqual typeof verified, 'object'
      for key,val of claims
        assert.strictEqual verified.body[key], val
      done()
  it 'fails to verify a modified jwt header', (done) ->
    jwt = spJwt.create foo:'bar'
    jwtSplit = jwt.split '.'
    jwtSplit[0] = extendBase64Object jwtSplit[0], foo:'bar'
    jwt = jwtSplit.join()
    spJwt.verify jwt, (err, verified) ->
      assert.strictEqual err.message, 'Jwt cannot be parsed'
      done()
  it 'fails to verify a modified jwt body', (done) ->
    jwt = spJwt.create foo:'bar'
    jwtSplit = jwt.split '.'
    jwtSplit[1] = extendBase64Object jwtSplit[1], foo:'bar'
    jwt = jwtSplit.join()
    spJwt.verify jwt, (err, verified) ->
      assert.strictEqual err.message, 'Jwt cannot be parsed'
      done()
  it 'fails to verify a corrupted jwt signature', (done) ->
    jwt = spJwt.create foo:'bar'
    jwt += 'broken'
    spJwt.verify jwt, (err, verified) ->
      assert.strictEqual err.message, 'Signature verification failed'
      done()
  it 'accepts and expiration date as a second parameter', (done) ->
    exp = new Date()
    exp.setMinutes exp.getMinutes() + 1
    jwt = spJwt.create {}, exp
    spJwt.verify jwt, (err, verified) ->
      assert.strictEqual verified.body.exp, exp.getTime() // 1000
      done()
  it 'fails to verify an expired jwt', (done) ->
    exp = new Date()
    exp.setMinutes exp.getMinutes() - 1
    jwt = spJwt.create {}, exp
    spJwt.verify jwt, (err, verified) ->
      assert.strictEqual err.message, 'Jwt is expired'
      done()