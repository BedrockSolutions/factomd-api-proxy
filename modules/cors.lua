local get_header = require('shared').get_header

local function options_body(message, ...)
  local formattedMsg = string.format(message, ...)
  local res_body = string.format('{"message": "CORS Pre-flight: %s"}', formattedMsg)
  ngx.header['Content-Length'] = string.len(res_body)
  ngx.print(res_body)
end

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

  for pattern in string.gmatch(allow_origin, '%S+')
  do
    ngx.log(ngx.INFO, string.format('Origin pattern: %q', pattern))

    if string.match(origin, pattern) then
      return true
    end
  end

  return false
end

local function set_common_cors_headers(allow_origin, origin)
  if is_wildcard_origin(allow_origin) then
    ngx.header['Access-Control-Allow-Origin'] = '*'
    ngx.header['Access-Control-Allow-Credentials'] = 'false'
  else
    ngx.header['Access-Control-Allow-Origin'] = origin
    ngx.header['Access-Control-Allow-Credentials'] = 'true'
    ngx.header['Varies'] = 'Origin'
  end
end

local function handle_options(allow_origin, origin)
  if not is_origin_allowed(allow_origin, origin) then
    options_body('Origin %s is not allowed', origin)
    return
  end

  -- Get the requested method so that it can be validated
  local req_method = get_header('Access-Control-Request-Method')
  local uri = ngx.var.uri

  -- The only methods that can be requested are GET and POST
  -- and only for specific URLs
  if req_method == 'GET' and uri == '/' then
    ngx.header['Access-Control-Allow-Methods'] = 'GET'

  elseif req_method == 'POST' and uri == '/v2' then
    ngx.header['Access-Control-Allow-Methods'] = 'POST'

  else
    options_body('The requested method %s is not allowed', req_method)
    return
  end

  set_common_cors_headers(allow_origin, origin)
  ngx.header['Access-Control-Allow-Headers'] = get_header('Access-Control-Request-Headers')

  options_body('Origin %s is allowed', origin)
end

local function handle_get_and_post(allow_origin, origin)
  if is_origin_allowed(allow_origin, origin) then
    set_common_cors_headers(allow_origin, origin)
  end
end

local function go(config)
  local allow_origin = config.allow_origin

  if is_cors_disabled(allow_origin) then
    return
  end

  local method = ngx.req.get_method()
  local origin = get_header('Origin')
  local uri = ngx.var.uri

  if method == 'OPTIONS' then
    handle_options(allow_origin, origin)

  elseif method == 'GET' and uri == '/' then
    handle_get_and_post(allow_origin, origin)

  elseif method == 'POST' and uri == '/v2' then
    handle_get_and_post(allow_origin, origin)
  end
end

return {
  go = go,
}
