stormpath = require 'stormpath'
jwt = require './jwt'
async = require 'async'
extend = require 'extend'
lru = require 'lru-cache'

CACHE_TIMEOUT = 1000 * 60 * 30     # 30 minutes
CACHE_MAX_ENTRIES = 100

apiLRUCache = lru
  max: CACHE_MAX_ENTRIES
  maxAge: CACHE_TIMEOUT


module.exports = class StormpathClient
  constructor: (@config) ->
    unless @config? then throw new Error 'Missing config object'
    requiredParams = ['id','secret','application_href','idsite_callback', 'idsite_logouturl', 'organization_key']
    for param in requiredParams
      unless @config[param]?
        throw new Error "Missing constructor configuration parameter: #{param}."

      @client = new stormpath.Client
        apiKey: new stormpath.ApiKey @config.id, @config.secret
        timeout: 10000 #ms (i.e. 10 seconds)

    @jwt = new jwt @config



  ###
  # returns a reference to an application object
  # expects a callback that takes an error param and application param
  ###
  getApplication: (callback) ->
    @client.getApplication @config.application_href, (err, application) ->
      if err
        switch err.inner?.code
          when 'ECONNREFUSED'
            err = new Error 'Connection to Stormpath failed. Check the config application_href'
          when 'ETIMEDOUT'
            err = new Error 'Connection to Stormpath timed out. Check Stormpath server status'
        return callback err

      callback null, application

  ###
  # @param {string} sub - subscriber url
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
  # This is a private function, execute via call, passing in the appropriate 'this' context
  # e.g. genIdSiteUrl.call(this, ....)
  # @param {string} [state] - any value to be preserved after calling back.
  #     Can be used, for example, to preserve the originally requested url, so you can
  #     redirect the user there after validating their login
  # @param {function} {callback} - callback function takes two parameters, error and url.
  # @param {boolean} {logout} - flag for whether we are generating a logout url or not
  ###
  genIdSiteUrl = (state, logout=false, callback) ->
    if typeof state is 'function'
      callback = state
      state = ''

    @getApplication (err, application) =>
      return callback err if err

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
  #     Can be used, for example, to preserve the page logging out from.  This might be useful
  #     for example if logging right back in should return the user to the same page.
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
      if verified.body.state
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
    @jwt.verify jwtResponse, (err, verified) ->
      return callback err if err
      if verified.body.err then return callback new Error verified.body.err.message
      # status other than LOGOUT should be an error, handled above. Check again in case that assumption is wrong.
      unless verified.body.status is 'LOGOUT' then return callback new Error 'NOT LOGGED OUT'

      # The state is URI encoded transparently when gettind the ID Site url, but not automatically decoded.
      if verified.body.state
        verified.body.state = decodeURIComponent verified.body.state
      
      callback null, verified #execute our callback now we have been logged out


  ###
  # Handles authenticating api requests
  # @param {object} request  This is the node server request object
  # the callback is a standard node.js callback, taking an err param and authResult response
  # so it can be easily promisified by bluebird if needed
  ###
  authApiRequest: (request, callback) ->
    authorization = request?.headers?.authorization || request?.headers?.Authorization

    cleanRequest =              # only send stormpath api the needed information
      url: request.url
      headers:
        authorization: authorization
      method: request.method

    if apiLRUCache.has authorization                      # return immediately if we have item in cache
      callback null, apiLRUCache.get authorization
    else
      @getApplication (err, application) =>
        return callback err if err

        application.authenticateApiRequest request: cleanRequest, (err, authResult) =>
          return callback err if err

          @getUserData authResult.account.href, (err, username, userdata) ->
            return callback err if err

            userInfo =
              username: username
              userdata: userdata

            apiLRUCache.set authorization, userInfo
            callback err, userInfo


module.exports.jwt = jwt

module.exports.__testing =
  apiLRUCache: apiLRUCache