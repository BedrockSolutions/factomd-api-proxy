# Factomd API Proxy

A lightweight proxy, custom-built to enhance the factomd API port.

## Features:

* **CORS support:** Includes wildcard support and Lua pattern syntax for specifying 
allowed origins.

* **Health check support:** The `GET /` path returns a `200 OK`, which allows the API to
work correctly with cloud provider infrastructure, such as the GCP HTTP load balancer.

* **Strict protocol operation:** Only a very narrow range of HTTP verbs and URIs are
passed through to factomd, increasing security.

## Useful Links
      
  * [Base Image](https://hub.docker.com/r/openresty/openresty/)
  
  * [Lua Patterns](https://www.lua.org/pil/20.2.html)

## Supported tags and Dockerfile links

* [`latest` (*Dockerfile*)](https://github.com/BedrockSolutions/factomd-api-proxy/blob/master/Dockerfile)
  
* [`0.3.0` (*Dockerfile*)](https://github.com/BedrockSolutions/factomd-api-proxy/blob/0.3.0/Dockerfile)

## Environment variables

* **`ALLOW_ORIGIN`:** Configures CORS. Three modes of operation are supported:

  * `""`: Disables CORS. This is the default
  
  * `"*"`: Enables CORS in wildcard mode. This will allow all browsers to use
  the API.
  
  * `"<lua pattern> [<lua pattern>, ...]"`: Enables CORS only for origins that match one
  of the patterns in a space-delimited list. Some examples:
  
    * `^http://www%.foo%.com$`: Exact match of one domain
    
    * `^https?://.*foo%.com$`: Matches all origins ending in `foo.com`. Both http
    and https URLs match.
    
    * `^http://foo%.com$ ^http://bar%.com$`: Exact match for either `http://foo.com`
    or `http://bar.com`.
    
* **`API_URL`:** The URL of the upstream factomd instance. Defaults to `http://localhost:8088`.

* **`PORT`:** The port the proxy will listen on. Defaults to `8087`.

## Examples

### Proxy the API port to port 80
```bash
docker run -d -p 80:8087 --name factomd-api-proxy bedrocksolutions/factomd-api-proxy:<tag>
```

### Enable wildcard CORS
```bash
docker run -d -p 80:8087 -e "ALLOW_ORIGIN=*" --name factomd-api-proxy bedrocksolutions/factomd-api-proxy:<tag>
```

### Enable CORS for a specific domain
```bash
docker run -d -p 80:8087 -e "ALLOW_ORIGIN=^https?://www%.foo%.com$" --name factomd-api-proxy bedrocksolutions/factomd-api-proxy:<tag>
```

> Note: Since the `.` character has special meaning in Lua patterns, it needs to be
escaped with the `%` escape character.