local cjson = require('cjson')
local codes = require('json_rpc_codes')
local set_response_error = require('shared').set_response_error

return function(request, response)
  local options = {
    body = request.body,
    method = ngx.HTTP_POST,
  }

  local api_response = ngx.location.capture('/factomd', options)

  local data = { factomdResponse = api_response }
  local message

  if not api_response.body or api_response.body == '' then
    message = 'No response received from factomd'

  else
    local is_json_valid, rpc_response_or_error = pcall(cjson.decode, api_response.body)

    if not is_json_valid then
      data.parseError = rpc_response_or_error
      message = 'Unable to parse response from factomd'

    elseif type(rpc_response_or_error) ~= 'table' then
      message = 'Response from factomd is not a JSON object'

    else
      response.status = api_response.status
      response.json_rpc = rpc_response_or_error
      return
    end
  end

  set_response_error{response=response, code=codes.API_CALL_ERROR, data=data, message=message, status=ngx.HTTP_SERVICE_UNAVAILABLE}
end
