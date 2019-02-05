local cjson = require('cjson')
local set_response_error = require('shared').set_response_error

local function determine_request_type(request, response)
  local method = ngx.req.get_method()
  local uri = ngx.var.uri

  if method == 'GET' and uri == '/' then
    request.is_health_check = true

  elseif method == 'OPTIONS' and (uri == '/' or uri == '/v2') then
    request.is_cors_preflight = true

  elseif method == 'POST' and uri == '/v2' then
    request.is_api_call = true

  else
    local data = { method = method, uri = uri }

    local message = 'Unsupported method & uri combination'
    set_response_error{response=response, data=data, message=message, status=ngx.HTTP_NOT_FOUND}
    error()
  end
end

local function validate_request_body(request, response)
  ngx.req.read_body()
  local body = ngx.req.get_body_data()

  local code
  local data = {
    requestBody = body,
  }
  local message

  if request.is_api_call then
    local is_json_valid, rpc_call_or_error = pcall(cjson.decode, body)

    if not is_json_valid then
      code = -32700
      data.parseError = rpc_call_or_error
      message = 'Unable to parse request body JSON'

    else
      data.parsedRequest = rpc_call_or_error

      if type(rpc_call_or_error) ~= 'table' then
        message = 'Request body is not a JSON object'

      elseif rpc_call_or_error.jsonrpc ~= '2.0' then
        message = 'jsonrpc field is not 2.0'

      elseif rpc_call_or_error.id == nil or rpc_call_or_error.id == '' then
        message = 'id field is empty'

      elseif type(rpc_call_or_error.id) ~= 'string' and type(rpc_call_or_error.id) ~= 'number' then
        message = 'id field is not a string or number'

      elseif rpc_call_or_error.method == nil or rpc_call_or_error.method == '' then
        message = 'method field is empty'

      elseif type(rpc_call_or_error.method) ~= 'string' then
        message = 'method field is not a string'

      else
        request.body = body
        request.json_rpc = rpc_call_or_error
        response.json_rpc.id = request.json_rpc.id
      end
    end

  elseif body then
    data = { requestBody = body }
    message = 'No request body is allowed when making health check or preflight requests'
  end

  if message then
    set_response_error{response=response, code=code, data=data, message=message}
    error()
  end
end

return function(request, response)
  determine_request_type(request, response)

  validate_request_body(request, response)
end
