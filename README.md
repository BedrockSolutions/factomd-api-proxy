# Factomd API Proxy

A lightweight proxy, custom-built to enhance the factomd API port.

## Features:

* **CORS support:** Includes wildcard support and PERL regular expression syntax for specifying 
allowed origins.

* **SSL support:** High-grade SSL configuration that can deliver an A+ SSL Labs rating,
given a strong cert/key pair.

* **Health check support:** The `GET /` endpoint performs tests on the underlying factomd 
instance and returns a detailed diagnostic payload. This allows the API to work correctly 
with cloud provider load balancers, and streamlines the development of monitoring
infrastructure.

* **Access Control Whitelist:** An optional whitelist of IP addresses and/or networks can be
provided to restrict client connections.

* **Detailed logging:** API method names are logged, along with the usual information.

* **Strict protocol operation:** Only a very narrow range of HTTP verbs and URIs are
passed through to factomd.

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

### Primary options

* **`accessControlWhitelist`:** An array of allowed IP addresses and IP networks in CIDR format. If
omitted, all addresses are allowed to connect. Example:

```yaml
accessControlWhitelist:
- 192.168.0.0/16
- 1.2.3.4
```

* **`corsAllowOrigin`:** Configures CORS. Three modes of operation are supported:

  * `""`: Disables CORS. This is the default
  
  * `"*"`: Enables CORS in wildcard mode. This will allow all browsers to use
  the API.
  
  * `"<PERL Regular Expression>"`: Enables CORS only for origins that match the regular expression.
  Some examples:
  
    * `^http://www\\.foo\\.com$`: Exact match of one domain.
    
    * `^https?://.*foo\\.com$`: Matches all origins ending in `foo.com`. Both http
    and https URLs match.
    
    * `^http://(foo|bar)\\.com$`: Exact match for either `http://foo.com`
    or `http://bar.com`.
  
  > Note: Special characters, such as the period, need to be escaped with a backslash. To insert
  a literal backslash, escape it with a second backslash.
  
* **`factomdUrl`:** The URL of the upstream factomd instance. Defaults to `http://localhost:8088`.

* **`listenPort`:** The port the proxy will listen on. Defaults to `8080` for non-SSL operation,
and `8443` when SSL is enabled.

* **`ssl.certificate`:** Certificate chain in PEM format. If this plus `ssl.certificateKey` are present,
SSL will be enabled.
 
* **`ssl.certificateKey`:** Private key in PEM format. If this plus `ssl.certificate` are present,
SSL will be enabled.
 
### Secondary options

* **`nginx.clientBodyBufferSize`:** Specifies the size and the max size of the client
request buffer. The default should be plenty generous for the vast majority of API
operations.

* **`nginx.keepAliveRequests`:** Sets the maximum number of requests that can be served 
through one keep-alive connection. After the maximum number of requests are made, the 
connection is closed. The default value is tuned so that the proxy will work correctly
behind cloud load balancers.

* **`nginx.keepAliveTimeout`:** Sets a timeout during which a keep-alive client 
connection will stay open on the server side. The default value is tuned so that 
the proxy will work correctly behind cloud load balancers.

* **`ssl.ciphers`:** Specifies the enabled SSL ciphers. The ciphers are specified in the 
format understood by the OpenSSL library. The full list can be viewed by issuing the 
`openssl ciphers` command. The default is a very selective cipher suite that gives maximum
security.

* **`ssl.dhParam`:** Specifies the Diffie-Hellman key exchange parameters in PEM format.

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
corsAllowOrigin: '^https://www\\.foo\\.com$'

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
  
  certificateKey: |-
    -----BEGIN PRIVATE KEY-----
    ...private key goes here...
    -----END PRIVATE KEY-----
```

#### Docker run command

```bash
docker run -d \
  -p 443:8443 \
  -v /path/to/config/dir:/home/app/values \
  --name proxy bedrocksolutions/factomd-api-proxy:<tag>
```

## Useful Links
      
  * [Base Image](https://hub.docker.com/r/openresty/openresty/)
  