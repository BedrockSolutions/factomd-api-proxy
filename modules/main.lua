local api_call = require('api_call')
local cors = require('cors')
local health_check = require('health_check')
local log = require('log')
local parse_and_validate_request = require('parse_and_validate_request')

local function global_headers(ssl_enabled)
  ngx.header['Content-Security-Policy'] = "default-src 'none'"
  ngx.header['Content-Type'] = 'application/json; charset=utf-8'
  ngx.header['Referrer-Policy'] = 'same-origin'
  ngx.header['X-Content-Type-Options'] = 'nosniff'
  ngx.header['X-Frame-Options'] = 'SAMEORIGIN'
  ngx.header['X-XSS-Protection'] = '1; mode=block'

  if ssl_enabled then
    ngx.header['Strict-Transport-Security'] = 'max-age=63072000;'
  end
end

local function go(config)
  local is_request_valid, request = pcall(parse_and_validate_request.go, config)

  global_headers(config.ssl_enabled)
  cors.go(config, request)

  if is_request_valid then
    if request.is_health_check then
      health_check.go(config, request)

    elseif request.is_api_call then
      api_call.go(config, request)
    end
  else
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.print(string.format('{ "error": "%s" }', request.error))
  end

  log.go(config, request)
  ngx.exit(ngx.status)
end

return {
  go = go,
}