stormpath = require 'stormpath'
jwt = require './jwt'
async = require 'async'
extend = require 'extend'


      
module.exports = class StormpathClient
  constructor: (@config) ->
    unless @config? then throw new Error 'Missing config object'
    requiredParams = ['id','secret','application_href','idsite_callback', 'idsite_logouturl', 'organization_key']
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

    # utility function used below to do deep copy
    extendDeep = (a, b) ->
      extend true, a, b

    unless sub then return callback new Error 'sub url not provided'
    @client.getAccount sub, (err, account) ->
      return callback err if err
      unless account.status is 'ENABLED' then return callback new Error 'Account not enabled'
        
      offset = 0
      size = null
      customDataArray = []
      
      async.doWhilst (cb) ->
        account.getGroups {expand:'customData', offset:offset}, (err, groups) ->
          return cb err if err
          size = groups.size
          customDataArray.push g.customData for g in groups.items
          offset += groups.limit
          cb()
      , -> #test. do while true
        offset < size
      , (err) -> #done
        return callback err if err
        customDataArray = customDataArray.sort (a,b) -> (a.order or 0) - (b.order or 0)
        customDataObject = customDataArray.reduce extendDeep, {}

        delete customDataObject.order #will be the order of the last customData that had one. Not useful to caller
        callback null, account.username, customDataObject

  ###
  # This is a private function, execute via call, passing in the appropriate this context
  # @param {string} [state] - any value to be preserved after calling back.
  #     Can be used, for example, to preserve the originally requested url, so you can
  #     redirect the user there after validating their login
  # @param {function} {callback} - callback function takes two paramerers, error and url.
  # @param {boolean} {logout} - flag for whether we are generating a logout url or not
  ###
  genIdSiteUrl = (state, logout=false, callback) ->
    if typeof state is 'function'
      callback = state
      state = ''

    @client.getApplication @config.application_href, (err, application) =>
      if err
        if err.inner?.code is 'ECONNREFUSED'
          err = new Error 'Connection to Stormpath failed. Check the config application_href'
        return callback err

      params =
        state: state
        organizationNameKey: @config.organization_key
        showOrganizationField: true
        logout:  logout
        callbackUri: if logout then @config.idsite_logouturl else @config.idsite_callback

      callback null, application.createIdSiteUrl params      # all good, so call our callback with the url

  ###
  # Handles generating a login url
  # @param {string} [state] - any value to be preserved after calling back.
  #     Can be used, for example, to preserve the originally requested url, so you can
  #     redirect the user there after validating their login
  # @param {function} {callback} - callback function takes two paramerers, error and url.
  ###
  getIdSiteUrl: (state, callback) -> genIdSiteUrl.call(@, state, false, callback)

  ###
  # Handles generating a logout url
  # @param {string} [state] - any value to be preserved after calling back.
  #     Can be used, for example, to preserve the originally requested url, so you can
  #     redirect the user there after validating their login
  # @param {function} {callback} - callback function takes two paramerers, error and url.
  ###
  getIdSiteLogoutUrl: (state, callback) -> genIdSiteUrl.call(@, state, true, callback)

  ###
  # Handles login callbacks
  # @param {string} jwtResponse - response passed from the id site to your callback url.
  # Calls back with any error or the verified jwt resopnse object extended with user data
  ###
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

  ###
  # Handles logout callbacks
  # @param {string} jwtResponse - response passed from the id site to your callback url.
  # Calls back with any error or the verified jwt resopnse object extended with user data
  ###
  handleIdSiteLogout: (jwtResponse, callback) ->
    @jwt.verify jwtResponse, (err, verified) =>
      return callback err if err
      if verified.body.err then return callback new Error verified.body.err.message
      # status other than LOGOUT should be an error, handled above. Check again in case that assumption is wrong.
      unless verified.body.status is 'LOGOUT' then return callback new Error 'NOT LOGGED OUT'

      callback null #execute our callback now we have been logged out
    
module.exports.jwt = jwt