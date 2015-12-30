njwt = require 'njwt'

module.exports = class JWT
  constructor: (@config) ->
    unless @config?.secret?
      throw new Error "Missing constructor configuration.\n" +
        "Constructor parameter is an object that must contain secret"
  
  ###
    verify string or object jwt and callback with its object version
    Return object will contain header and body keys. Body contains all signed claims plus iat, exp and jti
  ###
  verify: (jwt, callback) ->
    njwt.verify jwt, @config.secret, callback

  ###
    create a jwt string by signing the passed claims.
    default expiration is 3600 seconds (1 hour). Can be changed with the second parameter
    @param {object} claims - object containing any claims to sign. The following will be created automatically:
    @param {string} claims.jti - unique ID for this JWT
    @param {number} claims.iat - creation timestamp IN SECONDS
    @param {number} claims.exp - expiration date IN SECONDS. May NOT be overwritten directly, use the second param.
    @param {date or number} expiration - expiration date as a Date object or timestamp IN MILISECONDS
    default is 1 hour from creation date
  ###
  create: (claims, expiration) ->
    jwt = njwt.create claims, @config.secret
    if expiration then jwt.setExpiration expiration
    jwt.compact()