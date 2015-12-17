

client = require '../lib/stormpath-client'
assert = require 'assert'

spc = new client id:'myid', secret:'mysecret', application_href:'myhref'

mockGroupData = (customDataArray) ->
  spc.client =
    getAccount: (sub, cb1) ->
      cb1 null, getGroups: (options, cb2) ->
        cb2 null, items:(customData:cd for cd in customDataArray)


describe 'getUserData', ->
  it 'returns and object with empty properties if a user has no groups', (done) ->
    mockGroupData []
    spc.getUserData '', (err, data) ->
      assert.deepEqual data, brands:[]
      done()

  context 'brands', ->
    it 'maps group customData brands to a brands array', (done) ->
      mockGroupData [
        {brand: brand1: true}
        {otherThing: stuff: true}
        {brand: brand2: true}
      ]
      spc.getUserData '', (err, data) ->
        assert.ifError err
        #order is not specified
        assert.deepEqual data.brands.length, 2
        assert 'brand1' in data.brands
        assert 'brand2' in data.brands
        done()
    it 'can include multiple brands per group', (done) ->
      mockGroupData [
        {brand:
          brand1: true
          brand2: true
        }
        {brand: brand3: true}
      ]
      spc.getUserData '', (err, data) ->
        assert.deepEqual data.brands, ['brand1', 'brand2', 'brand3']
        done()
    it "doesn't include the same brand more than once", (done) ->
      mockGroupData [
        {brand: brand1: true}
        {brand: brand1: true}
      ]
      spc.getUserData '', (err, data) ->
        assert.deepEqual data.brands, ['brand1']
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
      spc.getUserData '', (err, data) ->
        assert.deepEqual data.brands, [
          'brand4'
          'brand5'
          'brand2'
          'brand1'
          'brand3'
        ]
        done()
    it 'later groups may remove previously granted access', (done) ->
      mockGroupData [
        {brand: brand1: true}
        {brand: brand2: true}
        {brand: brand3: true}
        {
          brand: brand2: false
          order: 1
        }
      ]
      spc.getUserData '', (err, data) ->
        assert.deepEqual data.brands, ['brand1', 'brand3']
        done()



