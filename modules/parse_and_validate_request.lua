local cjson = require('cjson')

local function determine_request_type(request)
  local method = ngx.req.get_method()
  local uri = ngx.var.uri

  if method == 'GET' and uri == '/' then
    request.is_health_check = true

  elseif method == 'OPTIONS' and (uri == '/' or uri == '/v2') then
    request.is_cors_preflight = true

  elseif method == 'POST' and uri == '/v2' then
    request.is_api_call = true

  else
    request.error = string.format('%s %s is an unsupported method & uri combination', method, uri)
    error(request)
  end
end

local function validate_request_body(request)
  ngx.req.read_body()
  local body = ngx.req.get_body_data()

  if request.is_api_call then
    local is_json_valid, rpc_call_or_error = pcall(cjson.decode, body)

    if not is_json_valid then
      request.error = string.format('Unable to parse request body JSON: %s', rpc_call_or_error)

    elseif type(rpc_call_or_error) ~= 'table' then
      request.error = string.format('Expected body to contain a JSON RPC request object. Got %s instead', tostring(rpc_call_or_error))

    elseif rpc_call_or_error.jsonrpc ~= '2.0' then
      request.error = string.format('Expected the jsonrpc field to be the string 2.0. Got %s instead', tostring(rpc_call_or_error.jsonrpc))

    elseif rpc_call_or_error.id == nil or rpc_call_or_error.id == '' then
      request.error = 'Expected the id field to not be empty'

    elseif type(rpc_call_or_error.id) ~= 'string' and type(rpc_call_or_error.id) ~= 'number' then
      request.error = string.format('Expected the id field to be a string or number. Got %s instead', tostring(rpc_call_or_error.id))

    elseif rpc_call_or_error.method == nil or rpc_call_or_error.method == '' then
      request.error = 'Expected the method field to not be empty'

    elseif type(rpc_call_or_error.method) ~= 'string' then
      request.error = string.format('Expected the method field to be a string. Got %s instead', tostring(rpc_call_or_error.method))

    else
      request.body = body
      request.json_rpc_call = rpc_call_or_error
    end
  elseif body then
    request.error = 'No request body is allowed when making health check or preflight requests'
  end

  if request.error then
    error(request)
  end
end

local function go(config)
  local request = {
    is_health_check = false,
    is_cors_preflight = false,
    is_api_call = false,
    error = nil,
    api_method = nil,
    body = nil,
  }

  determine_request_type(request)

  validate_request_body(request)

  return request
end

return {
  go = go,
}