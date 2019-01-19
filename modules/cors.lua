local get_header = require('shared').get_header

local function options_body(message, ...)
  ngx.say(string.format('CORS Pre-flight: ' .. message, ...))
end

local function is_wildcard_origin(allow_origin)
  return allow_origin == '*'
end

local function is_cors_disabled(allow_origin)
  return allow_origin == nil or allow_origin == ''
end

local function is_origin_allowed(allow_origin, origin)
  if is_wildcard_origin(allow_origin)
  then
    return true
  end

  for pattern in string.gmatch(allow_origin, '%S+')
  do
    ngx.log(ngx.INFO, string.format('Origin pattern: %q', pattern))

    if string.match(origin, pattern)
    then
      return true
    end
  end

  return false
end

local function set_common_cors_headers(allow_origin, origin)
  if is_wildcard_origin(allow_origin)
  then
    ngx.header['Access-Control-Allow-Origin'] = '*'
    ngx.header['Access-Control-Allow-Credentials'] = 'false'
  else
    ngx.header['Access-Control-Allow-Origin'] = origin
    ngx.header['Access-Control-Allow-Credentials'] = 'true'
    ngx.header['Varies'] = 'Origin'
  end
end

local function handle_options(allow_origin, origin)
  if not is_origin_allowed(allow_origin, origin)
  then
    options_body('Origin %q is not allowed', origin)
    return
  end

  -- Get the requested method so that it can be validated
  local req_method = get_header('Access-Control-Request-Method')

  -- The only method that can be requested is POST
  if req_method ~= 'POST'
  then
    options_body('The requested method %q is not allowed', req_method)
    return
  end

  set_common_cors_headers(allow_origin, origin)
  ngx.header['Access-Control-Allow-Methods'] = 'OPTIONS, POST'
  ngx.header['Access-Control-Allow-Headers'] = get_header('Access-Control-Request-Headers')

  options_body('Origin %q is allowed', origin)
end

local function handle_post(allow_origin, origin)
  if is_origin_allowed(allow_origin, origin)
  then
    set_common_cors_headers(allow_origin, origin)
  end
end

local function go(config)
  local allow_origin = config.allow_origin

  if is_cors_disabled(allow_origin)
  then
    return
  end

  local method = ngx.req.get_method()
  local origin = get_header('Origin')

  if method == 'OPTIONS'
  then
    handle_options(allow_origin, origin)
  elseif method == 'POST'
  then
    handle_post(allow_origin, origin)
  end
end

return {
  go = go,
}
