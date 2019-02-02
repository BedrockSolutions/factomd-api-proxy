local shared = require('shared')
local get_header = shared.get_header
local set_response_message = shared.set_response_message

local function is_wildcard_origin(allow_origin)
  return allow_origin == '*'
end

local function is_cors_disabled(allow_origin)
  return allow_origin == nil or allow_origin == ''
end

local function is_origin_allowed(allow_origin, origin)
  if is_wildcard_origin(allow_origin) then
    return true
  end

  if ngx.re.find(origin, allow_origin) then
    return true
  else
    return false
  end
end

local function set_common_cors_headers(allow_origin, origin, response)
  if is_wildcard_origin(allow_origin) then
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Credentials'] = 'false'
  else
    response.headers['Access-Control-Allow-Origin'] = origin
    response.headers['Access-Control-Allow-Credentials'] = 'true'
    response.headers['Varies'] = 'Origin'
  end
end

local function handle_options(allow_origin, origin, response)
  if not is_origin_allowed(allow_origin, origin) then
    local data = { origin = origin }
    set_response_message{response=response, data=data, message='Origin is not allowed'}
    return
  end

  -- Get the requested method so that it can be validated
  local req_method = get_header('Access-Control-Request-Method')
  local uri = ngx.var.uri

  -- The only methods that can be requested are GET and POST
  -- and only for specific URLs
  if req_method == 'GET' and uri == '/' then
    response.headers['Access-Control-Allow-Methods'] = 'GET'

  elseif req_method == 'POST' and uri == '/v2' then
    response.headers['Access-Control-Allow-Methods'] = 'POST'

  else
    local data = { requestMethod = req_method, origin = origin }
    set_response_message{response=response, data=data, message='Request method is not allowed'}
    return
  end

  set_common_cors_headers(allow_origin, origin, response)
  response.headers['Access-Control-Allow-Headers'] = get_header('Access-Control-Request-Headers')

  local data = { requestMethod = req_method, origin = origin }
  set_response_message{response=response, data=data, message='Origin is allowed'}
end

local function handle_get_and_post(allow_origin, origin, response)
  if is_origin_allowed(allow_origin, origin) then
    set_common_cors_headers(allow_origin, origin, response)
  end
end

local function go(config, request, response)
  local allow_origin = config.allow_origin

  if is_cors_disabled(allow_origin) then
    set_response_message{response=response, message='CORS disabled'}
    return
  end

  local origin = get_header('Origin')

  if not origin then
    set_response_message{response=response, message='Origin header missing'}
    return
  end

  if request.is_cors_preflight then
    handle_options(allow_origin, origin, response)

  elseif request.is_health_check or request.is_api_call then
    handle_get_and_post(allow_origin, origin, response)
  end
end

return {
  go = go,
}
