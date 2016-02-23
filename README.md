# Balihoo Stormpath Client

This is a package for Balihoo services to interface with Stormpath authentication and user data.  It generally encapsulates standard Stormpath tasks, but also adds logic to retrieving and user customData according to our storage specs.


## Constructing the client

```coffeescript
client = require 'balihoo-stormpath-client'

config =
	id: 'myid'                #stormpath API id
	secret: 'mysecret'        #stormpath API secret
	application_href: 'myapp' #application_href for this site. This can be found in the Stormpath site.
	idsite_callback: 'myhref' #idsite_callback that handles successful login results. Must be set in Stormpath config too.
	idsite_logouturl: 'myhref'#idsite_logouturl that handles callbacks from logging out of Stormpath. Should remove local session too.
spc = new client config
```

## Logging In
Logging in to Stormpath is a three step process.

1. Redirect the user to the Stormpath ID Site.  This url is generated by getIdSiteUrl and contains some values that are generated by this client.
1. After loggin in, the user is redirected back to a specific url in your site with a jwtResponse. You MUST pass this to handleIdSiteCallback to verify that it is correct and fetch user data.
1. Preserve their login status on your site, perhaps via a cookie.
1. Redirect them back to the original page requested.
  
This client provides tools to handle each of these steps.

### getIdSiteUrl(state, callback)
An ID site url must be created for each login request, as it contains information specific to this user and contains a one-time use key.
  
A string state may be included and will appear in the response.  This is a useful way to preserve any state that will be needed after logging in, such as the originally requested url.

The result given to the callback will be the string url of the ID site, including any parameters in a signed JWT query string.

### handleIdSiteCallback(jwtResponse, callback)
Responses from the Stormpath ID Site will hit the specified url and contain a jwtResponse query string. This response must be verified before allowing access.

The result of this function, passed to the callback, will be the verified jwtResponse in object form.  It will also include a `userdata` key that contains any values retrieved from Stormpath.  Currently, this includes

* username (string) - the login user name.
* brands (array of string) - The brand keys the user should have access to.

This userdata may be expanded in the future.

## Logging Out
Logging out of both your application and Stormpath follows a similar structure to logging in.

1. Generate a redirect url with getIdSiteLogout and redirect the user here.
1. The id site logout page needs to verify the jwtResponse with handleIdSiteCallback.
1. Invalidate local session (clear the cookie, delete the session from the server, etc).
1. Redirect to some helpful logout url.  This could be the page they were originally on, which having no session should direct them to log back in.  It could also be some friendly landing page that requires no auth.

## Handling api/basic auth
### authApiRequest(request, callback)
This call allows the stormpath client to authenticate basic api requests. The request object is a standard node.js request object. Internally it is filtered to only pass the information needed by stormapth api

This method will process the request header looking for a basic auth signature and then verify the credentials against those in the stormpath database.

In order to use this scheme, an api key pair must be created in the stormpath administration interface. The api key id and api key secret must be used as the username and password respectively for the basic auth request

The callback function is called with the (err, username, userdata). The err object will be non-null on an error condition, and the username and userdata object will be returned on success (err = null)

## JWT
The Stormpath client uses [JWT](http://jwt.io) for various things.  The balihoo-stormpath-client uses an implementation that shares a secret key.  A few JWT functions are wrapped and exposed, and may be used directly if needed.  A built JWT client is available on a built stormpath-client object, or one may be created directly from the same stormpath-client require.

```coffeescript
bspc = require 'balihoo-stormpath-client'
config = require './config' #store your config elsewhere

#A JWT client is constructed with the Stormpath client using the same secret key
sp_client = new bspc config
sp_client.jwt.create foo:'bar'

#Or a JWT client can be created directly
jwt_client = new bspc.jwt config
jwt_client.create foo:'bar'
```

### create(claims, expiration)
Claims is an object containing all values that should be included.  Additional values may be added automatically, such as

* jti - a unique key for this jwt
* iat - creation timestamp in seconds
* exp - default expiration timestamp in seconds

exp may not be overwritten directly.  Instead, provide an expiration parameter to the create function as either a Date object or a timestamp in miliseconds.

The return value of this function is a string in the standard jwt format.  Note that unlike many functions in this library, jwt creation is synchronous.


### verify(jwt, callback)
Verify and decode a jwt and return its object representation.  This object contains header and body keys.  The body will contain all signed claims plus any automatically added.



