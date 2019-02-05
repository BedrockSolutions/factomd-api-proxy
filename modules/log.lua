local cjson = require('cjson')
local shared = require('shared')
local get_header = shared.get_header
local is_response_error = shared.is_response_error

local function get_log_level(response)
  local status = response.status

  if status >= 200 and status < 300 then
    return ngx.INFO
  elseif status >= 400 and status < 500 then
    return ngx.NOTICE
  elseif status >= 500 and status < 520 then
    return ngx.WARN
  else
    return ngx.ERROR
  end
end

local function log_entry(log_level, payload)
  ngx.log(log_level, cjson.encode(payload))
end

local function log_error(request, response, payload)
  payload.code = response.json_rpc.error.code
  payload.message = response.json_rpc.error.message

  if request.is_api_call and request.json_rpc and request.json_rpc.method then
    payload.jsonRpcMethod = request.json_rpc.method
  end

  log_entry(get_log_level(response), payload)
end

local function log_result(request, response, payload)
  local log_level = get_log_level(response)

  if request.is_cors_preflight then
    payload.message = 'Preflight allowed'

  elseif request.is_health_check then
    payload.message = 'Health check successful'

  elseif request.is_api_call then
    payload.jsonRpcMethod = request.json_rpc.method
    payload.message = 'API call successful'

  else
    log_level = ngx.ERROR
    payload.message = '!!! Logging Invariant Violation !!!'
  end

  log_entry(log_level, payload)
end

return function(request, response)
  local payload = {
    clientIP = request.client_ip,
    method = ngx.req.get_method(),
    origin = get_header('Origin'),
    status = response.status,
    uri = ngx.var.uri,
  }

  if is_response_error(response) then
    log_error(request, response, payload)
  else
    log_result(request, response, payload)
  end
end
