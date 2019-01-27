local shared = require('shared')
local get_json_rpc_request = shared.get_json_rpc_request
local is_status_ok = shared.is_status_ok

local function go(config, globals)
  local method = ngx.req.get_method()
  local status = ngx.status
  local uri = ngx.var.uri

  local message = ''
  if method == 'OPTIONS' and (uri == '/' or uri == '/v2') then
    local allowed_origin = ngx.header['Access-Control-Allow-Origin'] or 'DENIED'
    message = string.format('CORS Allowed Origin: %s', allowed_origin)

  elseif method == 'GET' and uri == '/' then
    local health_check_result = is_status_ok(status) and 'PASSED' or 'FAILED'
    message = string.format('Health Check Result: %s', health_check_result)

  elseif method == 'POST' and uri == '/v2' then
    if globals.is_rpc_request_valid then
      message = string.format('RPC Request Method: %s', get_json_rpc_request().method)
    else
      message = string.format('RPC Request Invalid: %s', globals.rpc_request_validation_error)
    end

  else
    message = 'Invalid Request'
  end

  local log_level = is_status_ok(status) and ngx.NOTICE or ngx.WARN
  ngx.log(log_level, string.format('status: %d, details: "%s"', ngx.status, message))
end

return {
  go = go,
}