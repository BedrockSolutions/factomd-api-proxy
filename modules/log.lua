local shared = require('shared')
local get_header = shared.get_header
local is_status_ok = shared.is_status_ok

local function go(config, request)
  local status = ngx.status

  local message = ''
  if request.error then
    message = string.format('Request Error: %s', request.error)

  elseif request.is_cors_preflight then
    local origin = get_header('Origin') or 'Unknown'
    local allowed_origin = ngx.header['Access-Control-Allow-Origin'] and 'ALLOWED' or 'DENIED'
    message = string.format('CORS Preflight: %s -> %s', origin, allowed_origin)

  elseif request.is_health_check then
    local health_check_result = is_status_ok(status) and 'PASSED' or 'FAILED'
    message = string.format('Health Check: %s', health_check_result)

  elseif request.is_api_call then
    message = string.format('API Call: %s', request.json_rpc_call.method)

  else
    message = 'Logging Invariant Violation'
  end

  local log_level = is_status_ok(status) and ngx.INFO or ngx.NOTICE
  ngx.log(log_level, string.format('status: %d, details: "%s"', status, message))
end

return {
  go = go,
}