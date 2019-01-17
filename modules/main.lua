local cors = require('cors')

local function set_content_type(mime_type)
  ngx.header['Content-Type'] = string.format('%s; charset=utf-8', mime_type)
end

local function init(config)
  cors.init(config)
end

local function go()
  local method = ngx.req.get_method()
  local uri = ngx.var.uri

  ngx.log(ngx.INFO, string.format('Method: %s, URI: %s', method, uri))

  if uri == '/' and method == 'GET'
  then
    set_content_type('text/html')
    ngx.say('Health check succeeded')
    ngx.exit(ngx.HTTP_OK)

  elseif uri == '/v2' and method == 'OPTIONS'
  then
    set_content_type('text/html')
    cors.go()
    ngx.exit(ngx.HTTP_OK)

  elseif uri == '/v2' and method == 'POST'
  then
    set_content_type('application/json')
    cors.go()

  else
    ngx.exit(ngx.HTTP_NOT_FOUND)
  end
end

return {
  init = init,
  go = go,
}