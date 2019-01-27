local cors = require('cors')
local health_check = require('health_check')
local log = require('log')
local security = require('security')

local function passthrough_api_call()
  local options = {
    always_forward_body = true,
    method = ngx.HTTP_POST,
  }

  ngx.req.read_body()
  local res = ngx.location.capture('/factomd', options)

  ngx.status = res.status
  ngx.header['Content-Length'] = res.header['Content-Length']
  ngx.print(res.body)
end

local function go(config)
  local method = ngx.req.get_method()
  local uri = ngx.var.uri

  local globals = {
    is_rpc_request_valid = false,
    rpc_request_validation_error = '',
  }

  security.go(config, globals)

  if method == 'GET' and uri == '/' then
    cors.go(config)
    health_check.go(config)

  elseif method == 'OPTIONS' and (uri == '/' or uri == '/v2') then
    cors.go(config)

  elseif method == 'POST' and uri == '/v2' then
    cors.go(config)
    if globals.is_rpc_request_valid then
      passthrough_api_call()
    else
      ngx.status = ngx.HTTP_BAD_REQUEST
    end

  else
    ngx.status = ngx.HTTP_NOT_FOUND
  end

  log.go(config, globals)
  ngx.exit(ngx.status)
end

return {
  go = go,
}