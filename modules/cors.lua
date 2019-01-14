local finish_request = require('shared').finish_request

local function finish_preflight(message, ...)
  finish_request(ngx.HTTP_OK, string.format('CORS Pre-flight: %s', message), ...)
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
    ngx.log(ngx.ERR, string.format('Origin pattern: %q', pattern))

    if string.match(origin, pattern)
    then
      return true
    end
  end

  return false
end

local function get_header(name)
  return ngx.req.get_headers()[name] or ''
end

local function set_common_cors_headers(allow_origin, origin)
  local is_wild = is_wildcard_origin(allow_origin)
  ngx.header['Access-Control-Allow-Origin'] = is_wild and '*' or origin
  ngx.header['Access-Control-Allow-Credentials'] = tostring(not is_wild)

  if not is_wild
  then
    ngx.header['Varies'] = 'Origin'
  end
end

local function handle_options(allow_origin, origin)
  if is_cors_disabled(allow_origin)
  then
    finish_preflight('No allowed origin configured')
  end

  if not is_origin_allowed(allow_origin, origin)
  then
    finish_preflight('Origin %q is not allowed', origin)
  end

  -- Get the requested method so that it can be validated
  local req_method = get_header('Access-Control-Request-Method')

  -- The only method that can be requested is POST
  if req_method ~= 'POST'
  then
    finish_preflight('The requested method %q is not allowed', req_method)
  end

  set_common_cors_headers(allow_origin, origin)
  ngx.header['Access-Control-Allow-Methods'] = 'POST'
  ngx.header['Access-Control-Allow-Headers'] = get_header('Access-Control-Request-Headers')

  finish_preflight('Origin %q is allowed', origin)
end

local function handle_post(allow_origin, origin)
  if not is_cors_disabled(allow_origin) and is_origin_allowed(allow_origin, origin)
  then
    set_common_cors_headers(allow_origin, origin)
  end
end

local function main(allow_origin)
  local method = ngx.req.get_method()
  local origin = get_header('Origin')

  if method == 'OPTIONS'
  then
    handle_options(allow_origin, origin)
  elseif method == 'POST'
  then
    handle_post(allow_origin, origin)
  else
    finish_request(ngx.HTTP_BAD_REQUEST, 'The HTTP method %q is not allowed', method)
  end
end

return {
  main = main,
}
