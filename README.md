# Factomd API Proxy

A lightweight proxy, custom-built to enhance the factomd API port.

## Features:

* **CORS support:** Includes wildcard support and Lua pattern syntax for specifying 
allowed origins.

* **SSL support:** High-grade SSL configuration that can deliver an A+ SSL Labs rating,
given a strong cert/key pair.

* **Health check support:** The `GET /` endpoint performs tests on the underlying factomd 
instance. This allows the API to work correctly with cloud provider infrastructure, such 
as the Cloudflare and Google Cloud load balancers.

* **Strict protocol operation:** Only a very narrow range of HTTP verbs and URIs are
passed through to factomd, increasing security.

* **Dynamic reconfiguration:** Edits to the YAML configuration files will cause an automatic
reload of the Nginx configuration, eliminating the need to restart the container in most cases.

* **Kubernetes ready:** The ability to split configuration into multiple files dovetails
perfectly with Kubernetes configuration patterns. Painlessly store most of the configuration 
in one or more ConfigMaps, while storing sensitive data such as the SSL private key in a 
Secret. No impedance mismatch!

## Supported tags and Dockerfile links

* [`latest` (*Dockerfile*)](https://github.com/BedrockSolutions/factomd-api-proxy/blob/master/Dockerfile)
  
* [`0.4.0` (*Dockerfile*)](https://github.com/BedrockSolutions/factomd-api-proxy/blob/0.4.0/Dockerfile)

## Configuration

All configuration is done via one or more YAML configuration files mounted under the 
`/home/app/values` directory. Configuration can be contained in a single file, multiple 
files, and multiple directories. The `/home/app/values` directory will be recursively 
traversed, and all files found will be merged to create the final configuration.

* **`corsAllowOrigin`:** Configures CORS. Three modes of operation are supported:

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
    
* **`factomdUrl`:** The URL of the upstream factomd instance. Defaults to `http://localhost:8088`.

* **`listenPort`:** The port the proxy will listen on. Defaults to `8080` for non-SSL operation,
and `8443` when SSL is enabled.

* **`ssl.certificate`:** Certificate chain in PEM format. If this plus `ssl.privateKey` are present,
SSL will be enabled.
 
* **`ssl.privateKey`:** Private key in PEM format. If this plus `ssl.certificate` are present,
SSL will be enabled.
 
## Examples

### Proxy a factomd instance running on http://localhost:8088 to port 80

#### Config file

None needed

#### Docker run command

```bash
docker run -d -p 80:8080 --name proxy bedrocksolutions/factomd-api-proxy:<tag>
```

### Proxy the Factom, Inc. courtesy node to port 80 and enable CORS wildcard mode

#### Config file

```yaml
corsAllowOrigin: '*'

factomdUrl: http://courtesy-node.factom.com
```

#### Docker run command

```bash
docker run -d \
  -p 80:8080 \
  -v /path/to/config.yaml:/home/app/values/config.yaml \
  --name proxy bedrocksolutions/factomd-api-proxy:<tag>
```

### Proxy the Factom, Inc. courtesy node, enable SSL, and enable CORS for a specific domain

> Note: this example uses multiple config files to illustrate that functionality

#### Config files

`general.yaml`
```yaml
corsAllowOrigin: '^https://www%.foo%.com$'

factomdUrl: http://courtesy-node.factom.com
```

`ssl.yaml`
```yaml
ssl:
  certificate: |-
    -----BEGIN CERTIFICATE-----
    ...certificate in the chain goes here...
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    ...certificate in the chain goes here...
    -----END CERTIFICATE-----
  
  privateKey: |-
    -----BEGIN PRIVATE KEY-----
    ...private key goes here...
    -----END PRIVATE KEY-----
```

> Note: Since the `.` character has special meaning in Lua patterns, it needs to be
escaped with the `%` escape character.

#### Docker run command

```bash
docker run -d \
  -p 443:8443 \
  -v /path/to/config/dir:/home/app/values \
  --name proxy bedrocksolutions/factomd-api-proxy:<tag>
```

## Useful Links
      
  * [Base Image](https://hub.docker.com/r/openresty/openresty/)
  
  * [Lua Patterns](https://www.lua.org/pil/20.2.html)
