stormpath = require 'stormpath'
njwt = require 'njwt'

module.exports = class StormpathClient
  constructor: (@config) ->
    unless @config.id? and @config.secret? and @config.application_href?
      throw new Error "Missing constructor configuration is missing.\n" +
        "Constructor parameter is an object that must contain id, secret, and applicatoin_href"

    @client = new stormpath.Client apiKey:new stormpath.ApiKey @config.id, @config.secret
    
  #todo: get all customData, not just brands
  #todo: order by customdata.order, default 0
  #todo: values later in the order that are value:false remove previous values
  #todo: customdata.brand might have many keys.
  # sub is the subscriber url, from the idsite jwtResponse body
  getUserData: (sub, callback) ->
    @client.getAccount sub, (err, account) ->
      return callback err if err
      account.getGroups expand:'customData', (err, groups) ->
        return callback err if err

        brands = []
        for item in groups.items
          brands.push key for key,val of item.customData.brand when val is true

        callback null, brands

  getIdSiteUrl: (callback) ->
    @client.getApplication @config.application_href, (err, application) ->
      return callback err if err
      #todo: make id site callback configurable
      #todo: include state, like the originally requested url. Whole url including protocol.
      url = application.createIdSiteUrl callbackUri: 'http://localhost:8081/stormpath/idSiteCallback'
      callback null, url

  verifyJwtResponse: (jwtResponse, callback) ->
    njwt.verify jwtResponse, @config.secret, callback
