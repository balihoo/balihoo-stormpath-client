stormpath = require 'stormpath'
njwt = require 'njwt'

module.exports = class StormpathClient
  constructor: (@config) ->
    unless @config.id? and @config.secret? and @config.application_href?
      throw new Error "Missing constructor configuration is missing.\n" +
        "Constructor parameter is an object that must contain id, secret, and applicatoin_href"

    @client = new stormpath.Client apiKey:new stormpath.ApiKey @config.id, @config.secret
    
  #note: in the future we may fetch other customData besides brands.  This may have different logic.
  # sub is the subscriber url, from the idsite jwtResponse body
  getUserData: (sub, callback) ->
    @client.getAccount sub, (err, account) ->
      return callback err if err
      account.getGroups expand:'customData', (err, groups) ->
        return callback err if err
        groups.items = groups.items.sort (a,b) -> (a.customData.order or 0) - (b.customData.order or 0)

        data = brands: []
        for item in groups.items
          for key,val of item.customData.brand
            if val is true and key not in data.brands
              data.brands.push key
            else if val is false
              index = data.brands.indexOf key
              if index >= 0
                data.brands.splice index, 1

        callback null, data

  getIdSiteUrl: (callback) ->
    @client.getApplication @config.application_href, (err, application) ->
      return callback err if err
      #todo: make id site callback configurable
      #todo: include state, like the originally requested url. Whole url including protocol.
      url = application.createIdSiteUrl callbackUri: 'http://localhost:8081/stormpath/idSiteCallback'
      callback null, url

  verifyJwtResponse: (jwtResponse, callback) ->
    njwt.verify jwtResponse, @config.secret, callback