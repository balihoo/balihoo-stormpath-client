stormpath = require 'stormpath'
jwt = require './jwt'

#recursively extend object
extend = (a, b) ->
  for key,val of b
    a[key] =
      if typeof val is 'object' and not Array.isArray val
        extend a[key] or {}, val
      else
        val
  a
      
module.exports = class StormpathClient
  constructor: (@config) ->
    unless @config? then throw new Error 'Missing config object'
    requiredParams = ['id','secret','application_href','idsite_callback','organization_key']
    for param in requiredParams
      unless @config[param]?
        throw new Error "Missing constructor configuration parameter: #{param}."

    @client = new stormpath.Client apiKey:new stormpath.ApiKey @config.id, @config.secret
    @jwt = new jwt @config

  ###
  # @param {string} sub - subscriber url, from the idsite jwtResponse body
  # @param {function} callback - parameters will be error, username, customData
  ###
  getUserData: (sub, callback) ->
    unless sub then return callback new Error 'sub url not provided'
    @client.getAccount sub, (err, account) ->
      return callback err if err
      unless account.status is 'ENABLED' then return callback new Error 'Account not enabled'
      
      account.getGroups expand:'customData', (err, groups) ->
        return callback err if err
        groups.items = groups.items.sort (a,b) -> (a.customData.order or 0) - (b.customData.order or 0)

        data = groups.items.reduce extend, {}

        callback null, account.username, data.customData or {}

  ###
  # @param {string} [state] - any value to be preserved after calling back.
  #     Can be used, for example, to preserve the originally requested url, so you can
  #     redirect the user there after validating their login
  ###
  getIdSiteUrl: (state, callback) ->
    if typeof state is 'function'
      callback = state
      state = ''

    @client.getApplication @config.application_href, (err, application) =>
      if err
        if err.inner?.code is 'ECONNREFUSED'
          err = new Error 'Connection to Stormpath failed. Check the config application_href'
        return callback err

      url = application.createIdSiteUrl
        callbackUri: @config.idsite_callback
        state: state
        organizationNameKey: @config.organization_key
        showOrganizationField: true

      callback null, url
    
  # @param {string} jwtResponse - response passed from the id site to your callback url.
  # Calls back with any error or the verified jwt resopnse object extended with user data
  handleIdSiteCallback: (jwtResponse, callback) ->
    @jwt.verify jwtResponse, (err, verified) =>
      return callback err if err
      if verified.body.err then return callback new Error verified.body.err.message
      # status other than AUTHENTICATED should be an error, handled above. Check again in case that assumption is wrong.
      unless verified.body.status is 'AUTHENTICATED' then return callback new Error 'NOT AUTHENTICATED'

      # The state is URI encoded transparently when gettind the ID Site url, but not automatically decoded.
      verified.body.state = decodeURIComponent verified.body.state

      @getUserData verified.body.sub, (err, username, userData) ->
        return callback err if err
        verified.body.username = username
        verified.body.userdata = userData
        callback err, verified
    
module.exports.jwt = jwt