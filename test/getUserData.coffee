
client = require '../lib/stormpath-client'
assert = require 'assert'

spc = new client id:'myid', secret:'mysecret', application_href:'myhref', idsite_callback:'myidhandler'

testAccount =
  username: 'test@test.test'
mockGroupData = (customDataArray) ->
  spc.client =
    getAccount: (sub, cb1) ->
      account =
        status: 'ENABLED'
        username: testAccount.username
        getGroups: (options, cb2) ->
          cb2 null, items:(customData:cd for cd in customDataArray)
      cb1 null, account

describe 'getUserData', ->
  it 'returns username', (done) ->
    mockGroupData []
    spc.getUserData 'sub', (err, username, data) ->
      assert.strictEqual username, testAccount.username
      done()
  it 'returns an object with empty properties if a user has no groups', (done) ->
    mockGroupData []
    spc.getUserData 'sub', (err, username, data) ->
      assert.deepEqual data, {}
      done()
  it 'returns error if account not enabled', (done) ->
    spc.client =
      getAccount: (sub, callback) ->
        callback null, status:'DISABLED'
    spc.getUserData 'sub', (err, username, data) ->
      assert.strictEqual err.message, 'Account not enabled'
      done()
  it 'returns error if no sub provided', (done) ->
    spc.getUserData undefined, (err, username, data) ->
      assert.strictEqual err.message, 'sub url not provided'
      done()
  it 'recursively merges arbitrary customData into one object', (done) ->
    mockGroupData [
      {brand: brand1: true}
      {otherThing: stuff: true}
      {brand: brand2: true}
      {notAnObject: 'its a string'}
      {really: nested: object: with: 'value'}
      {really: nested: string: 'foo'}
    ]
    spc.getUserData 'sub', (err, username, data) ->
      assert.ifError err
      #order is not specified
      assert.strictEqual Object.keys(data).length, 4
      assert.deepEqual Object.keys(data.brand).length, 2
      assert.strictEqual data.brand['brand1'], true
      assert.strictEqual data.brand['brand2'], true
      assert.deepEqual Object.keys(data.otherThing).length, 1
      assert.strictEqual data.otherThing.stuff, true
      assert.strictEqual data.really.nested.object.with, 'value'
      assert.strictEqual data.really.nested.string, 'foo'
      done()
  it 'replaces array values', (done) ->
    mockGroupData [
      {thing: ['an','array']}
      {thing: ['of', 'strings']}
    ]
    spc.getUserData 'sub', (err, username, data) ->
      assert.strictEqual data.thing.length, 2
      assert.deepEqual data.thing, ['of', 'strings']
      done()
  it 'can include multiple brands per group', (done) ->
    mockGroupData [
      {brand:
        brand1: true
        brand2: true
      }
      {brand: brand3: true}
    ]
    spc.getUserData 'sub', (err, username, data) ->
      assert.deepEqual data.brand, {
        brand1: true
        brand2: true
        brand3: true
      }
      done()
  it "doesn't include the same brand more than once", (done) ->
    mockGroupData [
      {brand: brand1: true}
      {brand: brand1: true}
    ]
    spc.getUserData 'sub', (err, username, data) ->
      assert.deepEqual data.brand, brand1:true
      done()
  it 'orders groups when order is specified. Default order is 0', (done) ->
    mockGroupData [
      {
        brand: brand1: true
        order: 5
      }
      {
        brand: brand2: true
        order: 2
      }
      {
        brand: brand3: true
        order: 6
      }
      {
        brand: brand4: true
        #no order, implies 0
      }
      {
        brand: brand5: true
        order: 1
      }
    ]
    spc.getUserData 'sub', (err, username, data) ->
      assert.deepEqual data.brand, {
        brand4: true
        brand5: true
        brand2: true
        brand1: true
        brand3: true
      }
      done()
  it 'later groups may overwrite previously granted access', (done) ->
    mockGroupData [
      {brand: brand1: true}
      {brand: brand2: true}
      {brand: brand3: true}
      {
        brand: brand2: false
        order: 1
      }
    ]
    spc.getUserData 'sub', (err, username, data) ->
      assert.deepEqual data.brand, {
        brand1: true
        brand2: false
        brand3: true
      }
      done()



