# Balihoo Stormpath Client

This is a package for Balihoo services to interface with Stormpath authentication and user data.  It generally encapsulates standard Stormpath tasks, but also adds logic to retrieving and user customData according to our storage specs.

## Example of usage

### Constructing the client

```coffeescript
client = require 'balihoo-stormpath-client'

config =
	id: 'myid'                #stormpath API id
	secret: 'mysecret'        #stormpath API secret
	application_href: 'myapp' #application_href for this site. This can be found in the Stormpath site.
	 
spc = new client config
```

### Logging In
todo

### Handling login response
Responses from the Stormpath ID Site will hit the specified url and contain a jwtResponse query string. This response must be verified before allowing access.

```coffeescript
spc.verifyJwtResponse jwtResponse, (err, verified) ->
  #verified is now an valid object
```

### Fetching User Data
todo
