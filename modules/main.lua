local cors = require('cors')

local function set_content_type(mime_type)
  ngx.header['Content-Type'] = string.format('%s; charset=utf-8', mime_type)
end

local function go(config)
  local method = ngx.req.get_method()
  local uri = ngx.var.uri

  ngx.log(ngx.INFO, string.format('Method: %s, URI: %s', method, uri))

  ngx.header['Strict-Transport-Security'] = 'max-age=63072000;'

  if uri == '/' and method == 'GET'
  then
    set_content_type('text/html')
    ngx.say('Health check succeeded')
    ngx.exit(ngx.HTTP_OK)

  elseif uri == '/v2' and method == 'OPTIONS'
  then
    set_content_type('text/html')
    cors.go(config)
    ngx.exit(ngx.HTTP_OK)

  elseif uri == '/v2' and method == 'POST'
  then
    set_content_type('application/json')
    cors.go(config)

  else
    ngx.exit(ngx.HTTP_NOT_FOUND)
  end
end

return {
  go = go,
}